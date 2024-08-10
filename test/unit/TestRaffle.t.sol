// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployContract} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract TestRaffle is Test {
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 entryFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    function setUp() external {
        DeployContract deployer = new DeployContract();

        (raffle, helperConfig) = deployer.DeployRaffle();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entryFee = config.entryFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertIfEnoughEthNotSent() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__sendMoreEthToEnterRafel.selector);
        raffle.enterRaffel();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffel{value: entryFee}();
        address player = raffle.getPlayer(0);
        assert(player == PLAYER);
    }

    function testRaffleEnterEmitEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        raffle.enterRaffel{value: entryFee}();
    }

    function testDontAllowToEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffel{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffel{value: entryFee}();
    }

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfStateIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffel{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public {
        vm.prank(PLAYER);
        raffle.enterRaffel{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffel{value: entryFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testPerformKeepOnlyRunIfCheckUpKeepReturnsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffel{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    function testPerformKeepRevertsIfCheckUpKeepReturnsFalse() public {
        vm.prank(PLAYER);
        raffle.enterRaffel{value: entryFee}();
        
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                address(raffle).balance,
                raffle.getPlayersCount(),
                uint256(raffle.getRaffleState()))
            );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndEnoughTimeHasPassed() {
        vm.prank(PLAYER);
        raffle.enterRaffel{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testCheckUpKeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndEnoughTimeHasPassed {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    function testFullfillRandomWordsCanOnlyBeCalledAferPerformUpkeep(uint256 randomRequestId) public raffleEnteredAndEnoughTimeHasPassed {
            vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));

    }


    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndEnoughTimeHasPassed {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffel{value: entryFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs 

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entryFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
