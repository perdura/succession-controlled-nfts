// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title IERC721SuccessionControlled
/// @notice ERC-721 extension enabling registry-controlled transfers for on-chain succession.
/// @dev When successionRegistryOf(user) returns non-zero, transfers of that user's tokens
///      MUST revert unless msg.sender equals the returned registry address.
interface IERC721SuccessionControlled is IERC721 {
    /// @notice Emitted when a succession registry is authorized for a user.
    /// @param user The token owner
    /// @param registry The authorized registry address
    event SuccessionRegistryAuthorized(address indexed user, address indexed registry);
    
    /// @notice Returns the succession registry authorized to transfer a user's tokens.
    /// @param user The token owner
    /// @return The authorized registry address, or address(0) if unrestricted
    function successionRegistryOf(address user) external view returns (address);
}