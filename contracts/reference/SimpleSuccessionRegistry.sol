// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/ISuccessionRegistry.sol";
import "./ControllerNFT.sol";

/// @title SimpleSuccessionRegistry
/// @notice Reference implementation of ISuccessionRegistry with time-based inactivity policies.
///         Single-subject registry (one per user). Supports 6-month or 1-year wait periods.
/// @author Tian (@tian0)
contract SimpleSuccessionRegistry is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ISuccessionRegistry
{
    error InvalidSubject();
    error ConditionsNotMet();
    error NotBeneficiary();
    error NoNFTsToTransfer();
    error NotFactory();
    error NotConfigured();
    error AlreadyConfigured();
    error ZeroAddress();
    error InsufficientSpace(uint256 currentCount, uint256 incomingCount, uint256 availableSlots);

    uint256 private constant SIX_MONTHS = 180 days;
    uint256 private constant ONE_YEAR = 365 days;

    enum WaitPeriod {
        SIX_MONTHS,
        ONE_YEAR
    }

    struct Policy {
        address beneficiary;
        WaitPeriod waitPeriod;
        uint64 lastCheckIn;
        bool configured;
    }

    ControllerNFT public controllerNFT;
    Policy public policy;

    event PolicyConfigured(address indexed beneficiary, WaitPeriod waitPeriod);
    event BeneficiaryUpdated(address indexed oldBeneficiary, address indexed newBeneficiary);
    event CheckedIn(uint64 timestamp);
    event SuccessionDetails(
        address indexed from,
        address indexed to,
        uint256 transferred,
        uint256 skipped
    );

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize registry clone.
    /// @dev Only callable by factory during deployment.
    function initialize(
        address _owner,
        address _controllerNFT,
        address _factory
    ) external initializer {
        if (_owner == address(0) || _controllerNFT == address(0)) revert ZeroAddress();
        if (msg.sender != _factory) revert NotFactory();

        __Ownable_init(_owner);
        __ReentrancyGuard_init();

        controllerNFT = ControllerNFT(_controllerNFT);
    }

    /// @notice Configure succession policy. Can only be called once.
    function setupPolicy(
        address beneficiary,
        WaitPeriod waitPeriod
    ) external onlyOwner {
        if (policy.configured) revert AlreadyConfigured();
        if (beneficiary == address(0)) revert ZeroAddress();

        policy = Policy({
            beneficiary: beneficiary,
            waitPeriod: waitPeriod,
            lastCheckIn: uint64(block.timestamp),
            configured: true
        });

        emit PolicyConfigured(beneficiary, waitPeriod);
    }

    /// @notice Update beneficiary address. Resets check-in timer.
    function updateBeneficiary(address newBeneficiary) external onlyOwner {
        if (!policy.configured) revert NotConfigured();
        if (newBeneficiary == address(0)) revert ZeroAddress();

        address oldBeneficiary = policy.beneficiary;
        policy.beneficiary = newBeneficiary;
        policy.lastCheckIn = uint64(block.timestamp);

        emit BeneficiaryUpdated(oldBeneficiary, newBeneficiary);
    }

    /// @notice Check in to prove activity and reset succession timer.
    function checkIn() external onlyOwner {
        if (!policy.configured) revert NotConfigured();

        policy.lastCheckIn = uint64(block.timestamp);
        emit CheckedIn(policy.lastCheckIn);
    }

    /// @inheritdoc ISuccessionRegistry
    function isSuccessionOpen(address subject) external view returns (bool) {
        if (subject != owner()) return false;
        if (!policy.configured) return false;

        uint256 waitPeriod = _getWaitPeriodSeconds();
        uint256 elapsed = block.timestamp - policy.lastCheckIn;

        return elapsed >= waitPeriod;
    }

    /// @inheritdoc ISuccessionRegistry
    /// @dev Transfers original token first, then inherited tokens.
    ///      Emits SuccessionDetails with transfer counts for indexers.
    function executeSuccession(address subject) external nonReentrant {
        if (subject != owner()) revert InvalidSubject();

        Policy memory _policy = policy;

        if (!_policy.configured) revert NotConfigured();
        if (msg.sender != _policy.beneficiary) revert NotBeneficiary();

        uint256 waitPeriod = _getWaitPeriodSeconds();
        uint256 elapsed = block.timestamp - _policy.lastCheckIn;
        if (elapsed < waitPeriod) revert ConditionsNotMet();

        address owner_ = owner();
        uint256[] memory allTokens = controllerNFT.getUserOwnedTokens(owner_);
        if (allTokens.length == 0) revert NoNFTsToTransfer();

        (uint256[] memory orderedTokens, uint256 count) = _orderTokens(owner_, allTokens);

        uint256 beneficiaryTokenCount = controllerNFT.getUserOwnedTokens(_policy.beneficiary).length;
        uint256 maxTokens = controllerNFT.MAX_INHERITED_TOKENS();
        uint256 availableSlots = maxTokens > beneficiaryTokenCount
            ? maxTokens - beneficiaryTokenCount
            : 0;

        if (availableSlots == 0) {
            revert InsufficientSpace(beneficiaryTokenCount, count, 0);
        }

        uint256 tokensToTransfer = count > availableSlots ? availableSlots : count;

        for (uint256 i = 0; i < tokensToTransfer; i++) {
            IERC721(address(controllerNFT)).safeTransferFrom(
                owner_,
                _policy.beneficiary,
                orderedTokens[i]
            );
        }

        uint256 skipped = count - tokensToTransfer;

        emit SuccessionExecuted(owner_, _policy.beneficiary);
        emit SuccessionDetails(owner_, _policy.beneficiary, tokensToTransfer, skipped);
    }

    function getPolicy() external view returns (Policy memory) {
        return policy;
    }

    function getBeneficiary() external view returns (address) {
        return policy.beneficiary;
    }

    /// @notice Get registry status including time until succession opens.
    function getStatus() external view returns (
        bool configured,
        address beneficiary,
        WaitPeriod waitPeriod,
        uint64 lastCheckIn,
        uint256 secondsUntilOpen,
        bool isOpen
    ) {
        configured = policy.configured;

        if (!configured) {
            return (false, address(0), WaitPeriod.SIX_MONTHS, 0, 0, false);
        }

        beneficiary = policy.beneficiary;
        waitPeriod = policy.waitPeriod;
        lastCheckIn = policy.lastCheckIn;

        uint256 waitPeriodSeconds = _getWaitPeriodSeconds();
        uint256 elapsed = block.timestamp - policy.lastCheckIn;

        if (elapsed >= waitPeriodSeconds) {
            secondsUntilOpen = 0;
            isOpen = true;
        } else {
            secondsUntilOpen = waitPeriodSeconds - elapsed;
            isOpen = false;
        }
    }

    function _getWaitPeriodSeconds() internal view returns (uint256) {
        return policy.waitPeriod == WaitPeriod.SIX_MONTHS ? SIX_MONTHS : ONE_YEAR;
    }

    function _orderTokens(
        address owner_,
        uint256[] memory allTokens
    ) internal view returns (uint256[] memory orderedTokens, uint256 count) {
        orderedTokens = new uint256[](allTokens.length);
        count = 0;

        uint256 originalToken = controllerNFT.originalTokenId(owner_);

        for (uint256 i = 0; i < allTokens.length; i++) {
            if (allTokens[i] == originalToken && allTokens[i] != 0) {
                orderedTokens[count++] = allTokens[i];
                break;
            }
        }

        for (uint256 i = 0; i < allTokens.length; i++) {
            if (allTokens[i] != originalToken && allTokens[i] != 0) {
                orderedTokens[count++] = allTokens[i];
            }
        }
    }
}