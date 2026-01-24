// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title ISuccessionRegistry
/// @notice Minimal interface for on-chain succession registries.
/// @dev Implementations SHOULD deploy separate instances per subject for security.
///      Multi-subject registries create centralization risk and honeypot attack vectors.
///      Implementations define policy logic, access control, and griefing protection.
interface ISuccessionRegistry {
    /// @notice Emitted when succession is executed.
    /// @param from Previous controller
    /// @param to New controller
    event SuccessionExecuted(address indexed from, address indexed to);

    /// @notice Check if succession conditions are met for a subject.
    /// @param subject Address whose succession status to query
    /// @return True if succession can be executed
    function isSuccessionOpen(address subject) external view returns (bool);

    /// @notice Execute succession for a subject.
    /// @dev MUST revert if isSuccessionOpen(subject) returns false.
    ///      MUST emit SuccessionExecuted on success.
    /// @param subject Address whose succession to execute
    function executeSuccession(address subject) external;
}