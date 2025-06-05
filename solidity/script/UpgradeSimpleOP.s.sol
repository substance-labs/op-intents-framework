// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { Optimism7683 } from "../src/Optimism7683.sol";

import { ICreateX } from "./utils/ICreateX.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract UpgradeSimple is Script {
    function run() public {
        uint256 proxyAdminOwner = vm.envUint("DEPLOYER_PK");

        address routerProxy = vm.envAddress("ROUTER_ADDRESS");
        address proxyAdmin = vm.envAddress("PROXY_ADMIN");

        vm.startBroadcast(proxyAdminOwner);

        address newRouterImpl = deployImplementation();

        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(routerProxy), newRouterImpl);

        vm.stopBroadcast();

        // solhint-disable-next-line no-console
        console2.log("New Implementation:", newRouterImpl);
    }

    function deployImplementation() internal returns (address routerImpl) {
        address permit2 = vm.envAddress("PERMIT2");

        routerImpl = address(new Optimism7683(permit2));
    }
}
