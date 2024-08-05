// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployContract} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract TestRaffle is Test {
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
    }

    function testRaffleState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
}
