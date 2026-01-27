// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IERC721SuccessionControlled.sol";

/// @title ControllerNFT
/// @notice Reference implementation of IERC721SuccessionControlled with storage limits griefing protection.
///         Each address mints once. Transfers restricted to authorized succession registry.
/// @author Tian (@tian0)
contract ControllerNFT is ERC721, Ownable, IERC721SuccessionControlled {
    error AlreadyMinted();
    error RegistryOnly();
    error CannotBurnOriginalToken();
    error NotAuthorized();
    error NotTrustedFactory();
    error ZeroAddress();
    error RegistryAlreadySet();
    error TokenNotFound();
    error InheritedTokenLimitExceeded(
        uint256 currentCount, uint256 incomingCount, uint256 maxAllowed
    );

    uint256 public constant MAX_INHERITED_TOKENS = 8;

    uint256 private _nextTokenId = 1;
    uint256 public totalMinted;
    mapping(address user => bool) private _hasMinted;
    mapping(address user => uint256) private _originalTokenId;
    mapping(address user => uint256[]) private _userOwnedTokens;
    mapping(address user => address) private _successionRegistry;
    mapping(address factory => bool) private _trustedFactories;

    event ControllerNFTMinted(address indexed to, uint256 indexed tokenId);
    event ControllerNFTBurned(address indexed owner, uint256 indexed tokenId);
    event TrustedFactorySet(address indexed factory, bool trusted);

    constructor() ERC721("ControllerNFT", "CTRL") Ownable(msg.sender) {}

    /// @notice Mint a Controller NFT to caller. Each address can mint exactly once.
    function mint() external {
        _mintTo(msg.sender);
    }

    /// @notice Mint a Controller NFT to specified address.
    /// @dev Only callable by trusted factories for atomic estate creation.
    /// @param to Address to receive the NFT
    /// @return tokenId Minted token ID
    function mintFor(address to) external returns (uint256 tokenId) {
        if (!_trustedFactories[msg.sender]) revert NotTrustedFactory();
        return _mintTo(to);
    }

    function _mintTo(address to) internal returns (uint256 tokenId) {
        if (to == address(0)) revert ZeroAddress();
        if (_hasMinted[to]) revert AlreadyMinted();

        tokenId = _nextTokenId++;
        totalMinted++;

        _hasMinted[to] = true;
        _originalTokenId[to] = tokenId;

        _mint(to, tokenId);
        emit ControllerNFTMinted(to, tokenId);

        return tokenId;
    }

    /// @notice Burn an inherited Controller NFT. Cannot burn originally minted token.
    function burn(uint256 tokenId) external {
        if (_ownerOf(tokenId) != msg.sender) revert NotAuthorized();
        if (_originalTokenId[msg.sender] == tokenId) revert CannotBurnOriginalToken();

        _burn(tokenId);
        emit ControllerNFTBurned(msg.sender, tokenId);
    }

    /// @dev Mints and burns bypass registry check (from or to is zero).
    ///      Transfers require msg.sender to be the user's authorized registry.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address from)
    {
        from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            if (_successionRegistry[from] != auth) {
                revert RegistryOnly();
            }

            if (_userOwnedTokens[to].length >= MAX_INHERITED_TOKENS) {
                revert InheritedTokenLimitExceeded(
                    _userOwnedTokens[to].length, 1, MAX_INHERITED_TOKENS
                );
            }
        }

        _updateTokenTracking(from, to, tokenId);

        return super._update(to, tokenId, auth);
    }

    function approve(address, uint256) public pure override(ERC721, IERC721) {
        revert RegistryOnly();
    }

    function setApprovalForAll(address, bool) public pure override(ERC721, IERC721) {
        revert RegistryOnly();
    }

    /// @dev Required for parent ERC721._checkAuthorized to pass when registry calls transfer.
    ///      Works with _update for defense in depth: _update checks first, then parent calls this.
    function _isAuthorized(address owner, address spender, uint256)
        internal
        view
        override
        returns (bool)
    {
        return _successionRegistry[owner] == spender && spender != address(0);
    }

    function _updateTokenTracking(address from, address to, uint256 tokenId) internal {
        if (from == address(0) && to != address(0)) {
            _userOwnedTokens[to].push(tokenId);
        } else if (from != address(0) && to != address(0)) {
            _userOwnedTokens[to].push(tokenId);
            _removeTokenFromUser(from, tokenId);
        } else if (to == address(0)) {
            _removeTokenFromUser(from, tokenId);
        }
    }

    function _removeTokenFromUser(address user, uint256 tokenId) internal {
        uint256[] storage tokens = _userOwnedTokens[user];
        uint256 length = tokens.length;

        for (uint256 i = 0; i < length; i++) {
            if (tokens[i] == tokenId) {
                tokens[i] = tokens[length - 1];
                tokens.pop();
                return;
            }
        }

        revert TokenNotFound();
    }

    /// @notice Authorize succession registry for a user.
    /// @dev Only callable by trusted factories. One registry per user, immutable once set.
    function authorizeRegistry(address user, address registry) external {
        if (!_trustedFactories[msg.sender]) revert NotTrustedFactory();
        if (user == address(0) || registry == address(0)) revert ZeroAddress();
        if (_successionRegistry[user] != address(0)) revert RegistryAlreadySet();

        _successionRegistry[user] = registry;
        emit SuccessionRegistryAuthorized(user, registry);
    }

    /// @notice Set trusted factory status. Only contract owner.
    function setTrustedFactory(address factory, bool trusted) external onlyOwner {
        if (factory == address(0)) revert ZeroAddress();
        _trustedFactories[factory] = trusted;
        emit TrustedFactorySet(factory, trusted);
    }

    /// @inheritdoc IERC721SuccessionControlled
    function successionRegistryOf(address user) external view returns (address) {
        return _successionRegistry[user];
    }

    /// @notice Get current controller of an original holder's estate.
    /// @dev Returns address(0) if never minted or burned.
    function getCurrentController(address originalHolder) external view returns (address) {
        uint256 tokenId = _originalTokenId[originalHolder];
        if (tokenId == 0) return address(0);
        return _ownerOf(tokenId);
    }

    function hasMinted(address user) external view returns (bool) {
        return _hasMinted[user];
    }

    function originalTokenId(address user) external view returns (uint256) {
        return _originalTokenId[user];
    }

    function getUserOwnedTokens(address user) external view returns (uint256[] memory) {
        return _userOwnedTokens[user];
    }

    function isTrustedFactory(address factory) external view returns (bool) {
        return _trustedFactories[factory];
    }
}
