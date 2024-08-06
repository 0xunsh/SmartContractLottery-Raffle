// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployContract} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

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
}
