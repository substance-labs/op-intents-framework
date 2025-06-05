// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { Predeploys } from "./libs/Predeploys.sol";
import { IL2ToL2CrossDomainMessenger } from "./interfaces/IL2ToL2CrossDomainMessenger.sol";
import { Optimism7683Message } from "./libs/Optimism7683Message.sol";
import { OrderData, OrderEncoder } from "./libs/OrderEncoder.sol";
import { BasicSwap7683 } from "./BasicSwap7683.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Optimism7683
 * @author Substance Labs
 * @notice This contract builds on top of BasicSwap7683 as a messaging layer using Optimism.
 * @dev It integrates with the Optimism protocol for cross-chain event verification.
 */
contract Optimism7683 is BasicSwap7683, Ownable {
    // ============ Constants ============

    // ============ Public Storage ============
    IL2ToL2CrossDomainMessenger public immutable messenger =
        IL2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
    uint32 public immutable localDomain = uint32(block.chainid);
    mapping(uint32 => address) public destinationContracts;


    // ============ Events ============
    /**
     * @notice Event emitted when a destination contract is updated
     * @param chainId The chain ID for the destination
     * @param contractAddress The new contract address
     */
    event DestinationContractUpdated(uint256 indexed chainId, address contractAddress);
    
    // ============ Errors ============
    error InvalidDestinationContract();

    // ============ Constructor ============
    /**
     * @notice Initializes the Optimism7683 contract with the specified Prover and PERMIT2 address.
     * @param _permit2 The address of the permit2 contract
     */
    constructor(address _permit2) BasicSwap7683(_permit2) { }

    /**
     * @notice Initializes the contract with Optimism7683 contract
     */
    function initialize(address _owner) external {
        if (_owner == address(0)) revert InvalidDestinationContract();
        _transferOwnership(_owner);

        // Set the destination contract for the local domain
        destinationContracts[localDomain] = address(this);
     }

    // ============ Admin Functions ============
    function setDestinationContract(uint256 chainId, address contractAddress) external onlyOwner {
        if (contractAddress == address(0)) revert InvalidDestinationContract();
        destinationContracts[uint32(chainId)] = contractAddress;
        emit DestinationContractUpdated(chainId, contractAddress);
    }

    // ============ Internal Functions ============

    /**
     * @notice Dispatches a settlement instruction by emitting a Filled event that will be proven on the origin chain
     * @param _originDomain The domain to which the settlement message is sent
     * @param _orderIds The IDs of the orders to settle
     * @param _ordersFillerData The filler data for the orders
     */
    function _dispatchSettle(
        uint32 _originDomain,
        bytes32[] memory _orderIds,
        bytes[] memory _ordersFillerData
    ) internal override {
        bytes memory message = abi.encodeCall(
            this.handleSettle,
            (localDomain, bytes32(uint256(uint160(address(this)))), Optimism7683Message.encodeSettle(_orderIds, _ordersFillerData))
        );
        messenger.sendMessage(_originDomain, destinationContracts[_originDomain], message);
    }

    /**
     * @notice Dispatches a refund instruction by emitting a Refund event that will be proven on the origin chain
     * @param _originDomain The domain to which the refund message is sent
     * @param _orderIds The IDs of the orders to refund
     */
    function _dispatchRefund(
        uint32 _originDomain,
        bytes32[] memory _orderIds
    ) internal override {
        bytes memory message = abi.encodeCall(
            this.handleSettle,
            (localDomain, bytes32(uint256(uint160(address(this)))), Optimism7683Message.encodeRefund(_orderIds))
        );
        messenger.sendMessage(_originDomain, destinationContracts[_originDomain], message);
    }

    /**
     * @notice Handles incoming messages.
     * @dev Decodes the message and processes settlement or refund operations accordingly.
     * @param _messageOrigin The domain from which the message originates (unused in this implementation).
     * @param _messageSender The address of the sender on the origin domain (unused in this implementation).
     * @param _message The encoded message received via L2ToL2CrossDomainMessenger.
     */
    function handleSettle(uint32 _messageOrigin, bytes32 _messageSender, bytes calldata _message) external {
        (bool _settle, bytes32[] memory _orderIds, bytes[] memory _ordersFillerData) =
            Optimism7683Message.decode(_message);
        for (uint256 i = 0; i < _orderIds.length; i++) {
            if (_settle) {
                _handleSettleOrder(_messageOrigin, _messageSender, _orderIds[i], abi.decode(_ordersFillerData[i], (bytes32)));
            } else {
                _handleRefundOrder(_messageOrigin, _messageSender, _orderIds[i]);
            }
        }
    }

    function _localDomain() internal view override returns (uint32) {
        return localDomain;
    }
}
