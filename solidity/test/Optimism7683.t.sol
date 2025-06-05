// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test, Vm } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { TypeCasts } from "@hyperlane-xyz/libs/TypeCasts.sol";

import { BaseTest } from "./BaseTest.sol";
import { Optimism7683 } from "../src/Optimism7683.sol";
import { Optimism7683Message } from "../src/libs/Optimism7683Message.sol";
import { MockL2CrossDomainMessenger } from "./mock/MockL2CrossDomainMessenger.mock.sol";
import { Predeploys } from "../src/libs/Predeploys.sol";

/**
 * @title OptimismTestRouter
 * @notice Extended version of Optimism7683 for testing
 */
contract OptimismTestRouter is Optimism7683 {
    
    uint32[] internal _settledOrigins;
    bytes32[] internal _settledSenders;
    bytes32[] internal _settledOrderIds;
    bytes32[] internal _settledReceivers;
    
    uint32[] internal _refundedOrigins;
    bytes32[] internal _refundedSenders;
    bytes32[] internal _refundedOrderIds;
    
    function settledOrigins() external view returns (uint32[] memory) {
        return _settledOrigins;
    }
    
    function settledSenders() external view returns (bytes32[] memory) {
        return _settledSenders;
    }
    
    function settledOrderIds() external view returns (bytes32[] memory) {
        return _settledOrderIds;
    }
    
    function settledReceivers() external view returns (bytes32[] memory) {
        return _settledReceivers;
    }
    
    function refundedOrigins() external view returns (uint32[] memory) {
        return _refundedOrigins;
    }
    
    function refundedSenders() external view returns (bytes32[] memory) {
        return _refundedSenders;
    }
    
    function refundedOrderIds() external view returns (bytes32[] memory) {
        return _refundedOrderIds;
    }
    
    constructor(address _permit2) Optimism7683(_permit2) {}
    
    function dispatchSettle(
        uint32 _originDomain,
        bytes32[] memory _orderIds,
        bytes[] memory _ordersFillerData
    ) public {
        _dispatchSettle(_originDomain, _orderIds, _ordersFillerData);
    }
    
    function dispatchRefund(
        uint32 _originDomain,
        bytes32[] memory _orderIds
    ) public {
        _dispatchRefund(_originDomain, _orderIds);
    }
    
    // Override internal functions for testing
    function _handleSettleOrder(
        uint32 _messageOrigin,
        bytes32 _messageSender,
        bytes32 _orderId,
        bytes32 _receiver
    ) internal override {
        _settledOrigins.push(_messageOrigin);
        _settledSenders.push(_messageSender);
        _settledOrderIds.push(_orderId);
        _settledReceivers.push(_receiver);
        super._handleSettleOrder(_messageOrigin, _messageSender, _orderId, _receiver);
    }
    
    function _handleRefundOrder(
        uint32 _messageOrigin,
        bytes32 _messageSender,
        bytes32 _orderId
    ) internal override {
        _refundedOrigins.push(_messageOrigin);
        _refundedSenders.push(_messageSender);
        _refundedOrderIds.push(_orderId);
        super._handleRefundOrder(_messageOrigin, _messageSender, _orderId);
    }
    
    function getDomain() public view returns (uint32) {
        return _localDomain();
    }
}

/**
 * @title Optimism7683Test
 * @notice Tests for Optimism7683
 */
contract Optimism7683Test is BaseTest {
    using TypeCasts for address;
    
    // Test objects
    MockL2CrossDomainMessenger internal mockMessenger;
    OptimismTestRouter internal originRouter;
    OptimismTestRouter internal destRouter;
    
    // For easier identification
    bytes32 internal originRouterB32;
    bytes32 internal destRouterB32;
    
    // Chain IDs
    uint32 internal originChainId = 10;  // Optimism
    uint32 internal destChainId = 130;  // Unichain
    
    // Addresses
    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");
    
    event DestinationContractUpdated(uint256 indexed chainId, address contractAddress);
    
    // Set up the environment for testing
    function setUp() public override {
        super.setUp();
        
        // Deploy the mock messenger
        mockMessenger = new MockL2CrossDomainMessenger();
        
        // Set chain ID and etch the mock to predeploy address
        vm.chainId(originChainId);
        vm.etch(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER, address(mockMessenger).code);
        
        // Continue with the rest of the setup...
        originRouter = _deployRouter(owner);
        originRouterB32 = TypeCasts.addressToBytes32(address(originRouter));
        
        // Set chain ID for destination router
        vm.chainId(destChainId);
        vm.etch(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER, address(mockMessenger).code);
        destRouter = _deployRouter(owner);
        destRouterB32 = TypeCasts.addressToBytes32(address(destRouter));
        
        // Configure destinations
        vm.prank(owner);
        originRouter.setDestinationContract(destChainId, address(destRouter));
        
        vm.prank(owner);
        destRouter.setDestinationContract(originChainId, address(originRouter));
        
        // Reset chain ID to origin for most tests
        vm.chainId(originChainId);
    }
    
    // Helper to deploy a router through a proxy
    function _deployRouter(address _owner) internal returns (OptimismTestRouter) {
        OptimismTestRouter implementation = new OptimismTestRouter(permit2);
        
        ProxyAdmin admin = new ProxyAdmin();
        address adminOwner = makeAddr("adminOwner");
        admin.transferOwnership(adminOwner);
        
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(admin),
            abi.encodeCall(Optimism7683.initialize, (_owner))
        );
        
        return OptimismTestRouter(address(proxy));
    }
    
    // Test initialization values
    function test_initialize() public {
        // Check owner
        assertEq(originRouter.owner(), owner);
        
        // Check that local destination contract is set to self
        assertEq(originRouter.destinationContracts(originChainId), address(originRouter));
        
        // Check that domain is set correctly
        assertEq(originRouter.localDomain(), originChainId);
        
        // Check destination contract is set correctly
        assertEq(originRouter.destinationContracts(destChainId), address(destRouter));
    }
    
    // Test owner can set destination contracts
    function test_setDestinationContract() public {
        address newDestination = makeAddr("newDestination");
        uint32 newChainId = 42161; // Arbitrum
        
        // Non-owner should not be allowed to set destination contract
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        originRouter.setDestinationContract(newChainId, newDestination);
        
        // Owner should be able to set destination contract
        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(originRouter));
        emit DestinationContractUpdated(newChainId, newDestination);
        originRouter.setDestinationContract(newChainId, newDestination);
        
        // Verify the contract was set
        assertEq(originRouter.destinationContracts(newChainId), newDestination);
        
        // Should not be able to set zero address
        vm.prank(owner);
        vm.expectRevert(Optimism7683.InvalidDestinationContract.selector);
        originRouter.setDestinationContract(newChainId, address(0));
    }
    
    // Test dispatching settlement
    function test_dispatchSettle() public {
        MockL2CrossDomainMessenger messenger = MockL2CrossDomainMessenger(payable(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER));

        // Reset messages
        messenger.resetMessages();
        
        // Create test data
        bytes32[] memory orderIds = new bytes32[](2);
        orderIds[0] = bytes32(uint256(1));
        orderIds[1] = bytes32(uint256(2));
        
        bytes[] memory fillerData = new bytes[](2);
        fillerData[0] = abi.encode(bytes32(uint256(uint160(kakaroto))));
        fillerData[1] = abi.encode(bytes32(uint256(uint160(karpincho))));
        
        // Check the destination contract is set correctly
        address destContract = originRouter.destinationContracts(destChainId);
        console2.log("Destination contract for chain %d: %s", destChainId, destContract);
        console2.log("Expected destination router: %s", address(destRouter));
        
        // Dispatch the settlement
        originRouter.dispatchSettle(destChainId, orderIds, fillerData);
        
        // Check message count
        uint256 msgCount = messenger.getMessageCount();
        console2.log("Message count after dispatch: %d", msgCount);
        
        // Check that the message was sent to messenger
        (
            bytes32 hash,
            bytes memory message,
            uint256 destination,
            address target,
            address sender
        ) = messenger.getLastMessageDetails();
        
        console2.log("Destination in message: %d", destination);
        console2.log("Target in message: %s", target);
        
        // Verify destination
        assertEq(destination, destChainId);
        
        // Verify target
        assertEq(target, address(destRouter));
        
        // Verify sender
        assertEq(sender, address(originRouter));
        
        // Verify message content by decoding it
        bytes memory expectedMessage = abi.encodeCall(
            Optimism7683.handleSettle,
            (
                originChainId,
                TypeCasts.addressToBytes32(address(originRouter)),
                Optimism7683Message.encodeSettle(orderIds, fillerData)
            )
        );
        
        assertEq(keccak256(message), keccak256(expectedMessage));
    }
    
    // Test dispatching refund
    function test_dispatchRefund() public {
        MockL2CrossDomainMessenger messenger = MockL2CrossDomainMessenger(payable(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER));

        // Reset messages
        messenger.resetMessages();
        
        // Create test data
        bytes32[] memory orderIds = new bytes32[](2);
        orderIds[0] = bytes32(uint256(1));
        orderIds[1] = bytes32(uint256(2));
        
        // Dispatch the refund
        originRouter.dispatchRefund(destChainId, orderIds);
        
        // Check that the message was sent to messenger
        (
            bytes32 hash,
            bytes memory message,
            uint256 destination,
            address target,
            address sender
        ) = messenger.getLastMessageDetails();
        
        // Verify destination
        assertEq(destination, destChainId);
        
        // Verify target
        assertEq(target, address(destRouter));
        
        // Verify sender
        assertEq(sender, address(originRouter));
        
        // Verify message content by decoding it
        bytes memory expectedMessage = abi.encodeCall(
            Optimism7683.handleSettle,
            (
                originChainId,
                TypeCasts.addressToBytes32(address(originRouter)),
                Optimism7683Message.encodeRefund(orderIds)
            )
        );
        
        assertEq(keccak256(message), keccak256(expectedMessage));
    }
    
    // Test handling settlement messages
    function test_handleSettle_settlement() public {
        // Create test data
        bytes32[] memory orderIds = new bytes32[](2);
        orderIds[0] = bytes32(uint256(1));
        orderIds[1] = bytes32(uint256(2));
        
        bytes[] memory fillerData = new bytes[](2);
        fillerData[0] = abi.encode(bytes32(uint256(uint160(kakaroto))));
        fillerData[1] = abi.encode(bytes32(uint256(uint160(karpincho))));
        
        // Encode the settlement message
        bytes memory message = Optimism7683Message.encodeSettle(orderIds, fillerData);
        
        // Call handleSettle
        originRouter.handleSettle(destChainId, destRouterB32, message);
        
        // Check that the orders were handled correctly
        assertEq(originRouter.settledOrderIds().length, 2);
        assertEq(originRouter.settledOrderIds()[0], orderIds[0]);
        assertEq(originRouter.settledOrderIds()[1], orderIds[1]);
        
        assertEq(originRouter.settledOrigins()[0], destChainId);
        assertEq(originRouter.settledOrigins()[1], destChainId);
        
        assertEq(originRouter.settledSenders()[0], destRouterB32);
        assertEq(originRouter.settledSenders()[1], destRouterB32);
        
        assertEq(originRouter.settledReceivers()[0], bytes32(uint256(uint160(kakaroto))));
        assertEq(originRouter.settledReceivers()[1], bytes32(uint256(uint160(karpincho))));
    }
    
    // Test handling refund messages
    function test_handleSettle_refund() public {
        // Create test data
        bytes32[] memory orderIds = new bytes32[](2);
        orderIds[0] = bytes32(uint256(1));
        orderIds[1] = bytes32(uint256(2));
        
        // Encode the refund message
        bytes memory message = Optimism7683Message.encodeRefund(orderIds);
        
        // Call handleSettle
        originRouter.handleSettle(destChainId, destRouterB32, message);
        
        // Check that the orders were handled correctly
        assertEq(originRouter.refundedOrderIds().length, 2);
        assertEq(originRouter.refundedOrderIds()[0], orderIds[0]);
        assertEq(originRouter.refundedOrderIds()[1], orderIds[1]);
        
        assertEq(originRouter.refundedOrigins()[0], destChainId);
        assertEq(originRouter.refundedOrigins()[1], destChainId);
        
        assertEq(originRouter.refundedSenders()[0], destRouterB32);
        assertEq(originRouter.refundedSenders()[1], destRouterB32);
    }
}
