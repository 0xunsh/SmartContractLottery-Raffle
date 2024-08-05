// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployContract is Script {
    function DeployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entryFee,
            config.interval,
            config.vrfCoordinator,
            config.keyHash,
            config.callbackGasLimit,
            config.subscriptionId
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }

    function run() public returns (Raffle, HelperConfig) {}
}
