// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "erc6551/interfaces/IERC6551Registry.sol";
import "./ControllerNFT.sol";
import "./SimpleSuccessionRegistry.sol";

/// @title EstateFactory
/// @notice Atomic estate creation: NFT + Registry + TBA in one transaction.
///         Must be set as trusted factory in ControllerNFT before use.
/// @author Tian (@tian0)
contract EstateFactory is ReentrancyGuard {
    using Clones for address;

    error ZeroAddress();

    ControllerNFT public immutable controllerNFT;
    address public immutable registryImplementation;
    IERC6551Registry public immutable erc6551Registry;
    address public immutable erc6551AccountImplementation;

    event EstateCreated(
        address indexed user,
        uint256 indexed tokenId,
        address registry,
        address tba
    );

    constructor(
        address _controllerNFT,
        address _registryImplementation,
        address _erc6551Registry,
        address _erc6551AccountImplementation
    ) {
        if (_controllerNFT == address(0)) revert ZeroAddress();
        if (_registryImplementation == address(0)) revert ZeroAddress();
        if (_erc6551Registry == address(0)) revert ZeroAddress();
        if (_erc6551AccountImplementation == address(0)) revert ZeroAddress();

        controllerNFT = ControllerNFT(_controllerNFT);
        registryImplementation = _registryImplementation;
        erc6551Registry = IERC6551Registry(_erc6551Registry);
        erc6551AccountImplementation = _erc6551AccountImplementation;
    }

    /// @notice Create complete estate with NFT, succession registry, and token-bound account.
    /// @dev Deploys registry as EIP-1167 clone. Creates 6551 account via canonical registry.
    ///      Requires this factory to be trusted in ControllerNFT.
    /// @return tokenId Minted Controller NFT token ID
    /// @return registry Deployed succession registry clone
    /// @return tba ERC-6551 token-bound account
    function createEstate() external nonReentrant returns (
        uint256 tokenId,
        address registry,
        address tba
    ) {
        address user = msg.sender;

        tokenId = controllerNFT.mintFor(user);
        registry = registryImplementation.clone();

        SimpleSuccessionRegistry(registry).initialize(
            user,
            address(controllerNFT),
            address(this)
        );

        controllerNFT.authorizeRegistry(user, registry);

        tba = erc6551Registry.createAccount(
            erc6551AccountImplementation,
            bytes32(0),
            block.chainid,
            address(controllerNFT),
            tokenId
        );

        emit EstateCreated(user, tokenId, registry, tba);
    }
}