// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { Optimism7683 } from "../src/Optimism7683.sol";

import { ICreateX } from "./utils/ICreateX.sol";

contract OwnableProxyAdmin is ProxyAdmin {
    constructor(address _owner) {
        _transferOwnership(_owner);
    }
}

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployOptimism7683 is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");

        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin proxyAdmin = deployProxyAdmin();
        address routerImpl = deployImplementation();
        TransparentUpgradeableProxy proxy = deployProxy(routerImpl, address(proxyAdmin));

        vm.stopBroadcast();

        // solhint-disable-next-line no-console
        console2.log("Router Proxy:", address(proxy));
        console2.log("Implementation:", routerImpl);
        console2.log("ProxyAdmin:", address(proxyAdmin));
    }

    function deployProxyAdmin() internal returns (ProxyAdmin proxyAdmin) {
        string memory ROUTER_SALT = vm.envString("OPTIMISM7683_SALT");
        address proxyAdminOwner = vm.envOr("PROXY_ADMIN_OWNER", address(0));
        proxyAdmin = new OwnableProxyAdmin{salt: keccak256(abi.encode(ROUTER_SALT))}(proxyAdminOwner);
    }

    function deployImplementation() internal returns (address routerImpl) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address createX = vm.envAddress("CREATEX_ADDRESS");
        string memory ROUTER_SALT = vm.envString("OPTIMISM7683_SALT");
        uint256 localChainId = vm.envUint("LOCAL_CHAIN_ID");
        address permit2 = vm.envAddress("PERMIT2");
        bytes32 salt = keccak256(abi.encodePacked("impl",ROUTER_SALT, vm.addr(deployerPrivateKey)));

        bytes memory routerCreation = type(Optimism7683).creationCode;
        bytes memory routerBytecode = abi.encodePacked(routerCreation, abi.encode(permit2, localChainId));

        routerImpl = ICreateX(createX).deployCreate3(salt, routerBytecode);
    }

    function deployProxy(address routerImpl, address proxyAdmin) internal returns (TransparentUpgradeableProxy proxy) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address createX = vm.envAddress("CREATEX_ADDRESS");
        string memory ROUTER_SALT = vm.envString("OPTIMISM7683_SALT");
        address owner = vm.envAddress("ROUTER_OWNER");

        bytes32 salt = keccak256(abi.encodePacked("proxy", ROUTER_SALT, vm.addr(deployerPrivateKey)));

        bytes memory proxyCreation = type(TransparentUpgradeableProxy).creationCode;
        bytes memory proxyBytecode = abi.encodePacked(proxyCreation, abi.encode(
          routerImpl,
          proxyAdmin,
          abi.encodeWithSelector(Optimism7683.initialize.selector, owner)
        ));

        proxy = TransparentUpgradeableProxy(
          payable(ICreateX(createX).deployCreate3(salt, proxyBytecode))
        );
    }
}
