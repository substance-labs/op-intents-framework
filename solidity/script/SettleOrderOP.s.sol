// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { Optimism7683 } from "../src/Optimism7683.sol";

contract SettleOrder is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address router = vm.envAddress("ROUTER_ADDRESS");

        // Get the order ID from the environment or use a hardcoded value
        bytes32 orderId = vm.envBytes32("ORDER_ID");
        
        // Create an array of order IDs to settle
        bytes32[] memory orderIds = new bytes32[](1);
        orderIds[0] = orderId;

        vm.startBroadcast(deployerPrivateKey);
        
        try Optimism7683(router).settle(orderIds) {
            console2.log("Orders settled successfully");
        } catch Error(string memory reason) {
            console2.log("Settle failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Settle failed with low-level error");
            console2.logBytes(lowLevelData);
        }

        vm.stopBroadcast();
    }
}