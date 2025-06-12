// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title MockL2CrossDomainMessenger
 * @notice A mock implementation for testing
 */
contract MockL2CrossDomainMessenger {
    // Track messages
    bytes32[] public messageHashes;
    bytes[] public messages;
    uint256[] public destinations;
    address[] public targets;
    address[] public senders;
    
    // Return values
    bytes32 public returnHash = bytes32(uint256(1));
    
    // Cross-domain context for testing
    address public mockSender = address(0);
    uint256 public mockChainId = 0;
    
    // Reset function for testing
    function resetMessages() external {
        delete messageHashes;
        delete messages;
        delete destinations;
        delete targets;
        delete senders;
    }
    
    function sendMessage(
        uint256 _destination,
        address _target,
        bytes calldata _message
    ) external returns (bytes32) {
        // Record message details
        messageHashes.push(returnHash);
        messages.push(_message);
        destinations.push(_destination);
        targets.push(_target);
        senders.push(msg.sender);
        
        // Return a standard hash
        return returnHash;
    }
    
    // Test helper functions
    function getMessageCount() external view returns (uint256) {
        return messages.length;
    }
    
    function getLastMessageDetails() external view returns (
        bytes32 hash,
        bytes memory message,
        uint256 destination,
        address target,
        address sender
    ) {
        uint256 length = messages.length;
        if (length > 0) {
            uint256 index = length - 1;
            return (
                messageHashes[index],
                messages[index],
                destinations[index],
                targets[index],
                senders[index]
            );
        }
        return (bytes32(0), bytes(""), 0, address(0), address(0));
    }
    
    // Set the cross-domain message context for testing
    function setCrossDomainMessageContext(address _sender, uint256 _chainId) external {
        mockSender = _sender;
        mockChainId = _chainId;
    }
    
    // Implement the crossDomainMessageContext function to match the real interface
    function crossDomainMessageContext() external view returns (address, uint256) {
        return (mockSender, mockChainId);
    }
}