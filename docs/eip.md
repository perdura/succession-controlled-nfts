---
eip: XXXX
title: Succession-Controlled NFTs
description: ERC-721 extension enabling registry-controlled transfers for on-chain succession
author: Tian (@tian0) <tian0@perdura.xyz>
discussions-to: https://ethereum-magicians.org/t/draft-eip-succession-controlled-nfts/27662
status: Draft
type: Standards Track
category: ERC
created: 2026-01-27
requires: 721, 1167, 6551
---

## Abstract

This EIP defines a minimal interface for ERC-721 tokens that delegate transfer authority to succession registries. When a registry indicates succession conditions are met, only that registry may transfer the user's token. Combined with ERC-6551 token-bound accounts, this enables trustless digital estate planning: a single NFT can control multiple token-bound accounts, and when it transfers through succession, control of all linked accounts automatically transfers to the new holder.

The standard defines two interfaces: `IERC721SuccessionControlled` (an ERC-721 extension) and `ISuccessionRegistry` (policy verification). Implementations have freedom to define their own policy logic, whether time-based, guardian-approved, oracle-triggered, or any custom mechanism.

## Motivation

**How it works:** Mint an NFT, deploy a registry, link token-bound accounts, configure your policy. If you stop checking in, your beneficiary claims control.

Digital assets lack succession mechanisms. When someone dies or loses access permanently:

- Smart contract ownership doesn't transfer automatically
- Assets in DeFi positions, DAOs, and vaults remain locked
- Successors must locate and claim each asset individually
- No on-chain mechanism exists for planned, conditional transfers

Existing solutions address adjacent problems but not succession:

**Social Recovery** (ERC-4337, Safe): Designed for emergency key recovery, requires active guardian coordination, no time-based triggers.

**Token Bound Accounts** (ERC-6551): NFTs can own accounts, but no conditional transfer policies.

**Dead Man's Switch** (Sarcophagus): Requires off-chain storage dependencies.

**Custodial Services**: Ongoing fees, centralized trust, defeats sovereignty and self-custody.

This standard defines a minimal interface that makes any ERC-721 succession-capable. A single NFT can control an entire estate of token-bound accounts, and when succession conditions are met, one registry call transfers everything.

## Specification

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119 and RFC 8174.

### IERC721SuccessionControlled

An ERC-721 extension that delegates transfer authority to a succession registry.
```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IERC721SuccessionControlled is IERC721 {
    /// @notice Emitted when a succession registry is authorized for a user.
    event SuccessionRegistryAuthorized(address indexed user, address indexed registry);

    /// @notice Returns the succession registry authorized to transfer a user's tokens.
    /// @param user The token owner
    /// @return The authorized registry address, or address(0) if unrestricted
    function successionRegistryOf(address user) external view returns (address);
}
```

**Requirements:**

1. When `successionRegistryOf(user)` returns a non-zero address, transfers of that user's tokens MUST revert unless `msg.sender` equals the returned registry address.

2. Implementations SHOULD disable `approve()` and `setApprovalForAll()` for succession-controlled tokens to prevent circumventing registry restrictions.

3. The `SuccessionRegistryAuthorized` event MUST be emitted when a registry is authorized for a user.

4. Registry authorization is implementation-specific. Implementations MAY allow direct user authorization, factory-only authorization, or governance approval.

### ISuccessionRegistry

Minimal interface for succession policy verification and execution.
```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

interface ISuccessionRegistry {
    /// @notice Emitted when succession is executed.
    event SuccessionExecuted(address indexed from, address indexed to);

    /// @notice Check if succession conditions are met for a subject.
    /// @param subject Address whose succession status to query
    /// @return True if succession can be executed
    function isSuccessionOpen(address subject) external view returns (bool);

    /// @notice Execute succession for a subject.
    /// @param subject Address whose succession to execute
    function executeSuccession(address subject) external;
}
```

**Requirements:**

1. `isSuccessionOpen(subject)` MUST return `true` only when all succession conditions for `subject` are satisfied.

2. `executeSuccession(subject)` MUST revert if `isSuccessionOpen(subject)` returns `false`.

3. `executeSuccession(subject)` MUST emit `SuccessionExecuted` on successful transfer.

4. Policy logic is implementation-specific. Valid approaches include time-based inactivity, guardian approval, oracle triggers, or any combination.

**Security Consideration:** Implementations SHOULD deploy separate registry instances per subject. Multi-subject registries create centralization risk and honeypot attack vectors.

## Rationale

### Minimal Interface Design

The standard intentionally defines only two functions per interface. This allows maximum implementation flexibility while ensuring interoperability. A registry only needs `isSuccessionOpen()` and `executeSuccession()`. How it determines "open" is entirely up to the implementation.

### Subject Parameter

The `subject` parameter in registry functions supports both single-subject registries (recommended) and multi-subject registries. Single-subject deployments using EIP-1167 minimal proxies provide better security isolation at minimal gas cost.

### Registry-Controlled Transfers

Standard ERC-721 transfer functions (`transferFrom`, `safeTransferFrom`) remain callable but MUST revert when a registry is authorized. This preserves interface compatibility while enforcing succession rules. The registry becomes the sole transfer authority for controlled tokens.

### ERC-6551 Integration

This standard complements ERC-6551 token-bound accounts. A succession-controlled NFT can own multiple TBAs. When the NFT transfers through succession, the new holder automatically controls all linked TBAs and their contents, such that no per-account claims are required.

### Why Not Modify ERC-6551 Directly?

ERC-6551 defines account ownership, not transfer policies. Succession logic belongs at the NFT layer, not the account layer. This separation allows any NFT standard to become succession-capable without modifying account implementations.

## Backwards Compatibility

This standard extends ERC-721 and introduces no breaking changes. Existing ERC-721 tokens cannot retroactively become succession-controlled without migration to a new contract.

Implementations MUST maintain ERC-721 compatibility for wallets and marketplaces, even if transfer functions revert for controlled tokens.

## Reference Implementation

A complete reference implementation is available at [github.com/perdura/succession-controlled-nfts](https://github.com/perdura/succession-controlled-nfts).

The reference demonstrates:

- **ControllerNFT**: IERC721SuccessionControlled with one-mint-per-user, factory-authorized registries, and inheritance limits for griefing protection
- **SimpleSuccessionRegistry**: ISuccessionRegistry with time-based inactivity (6-month or 1-year wait periods) and check-in mechanism
- **EstateFactory**: Atomic deployment of NFT + Registry + ERC-6551 TBA using EIP-1167 minimal proxies

**Gas Benchmarks:**

| Operation | Gas Cost |
|-----------|----------|
| EstateFactory.createEstate() | ~384,000 |
| SimpleSuccessionRegistry.setupPolicy() | ~27,000 |
| SimpleSuccessionRegistry.checkIn() | ~8,400 |
| SimpleSuccessionRegistry.executeSuccession() | ~100,000 |

**Test Coverage:** 84 tests passing

The reference implementation uses time-based succession with check-ins. Alternative implementations could use guardian approval, oracle triggers, DAO voting, or any mechanism that satisfies the interface requirements.

## Security Considerations

### Registry Centralization

Implementations SHOULD deploy separate registry instances per subject (one registry per user). Multi-subject registries where a single contract manages succession for multiple users create centralization risks: a vulnerability affects all users, and concentrated value creates honeypot incentives. The reference implementation uses EIP-1167 minimal proxies for gas-efficient per-user deployment.

### Immutable Registry Authorization

Once a succession registry is authorized for a user, it cannot be changed in the reference implementation. Mutable authorization creates social engineering attack vectors where users could be tricked into authorizing malicious registries. The beneficiary address can still be updated within the registry itself.

### Beneficiary Contract Compatibility

If the beneficiary is a smart contract, it MUST implement `IERC721Receiver` or succession will revert. Compatible contracts include Gnosis Safe, ERC-4337 smart wallets, and any contract implementing the ERC-721 receiver interface. Implementations MAY validate beneficiary compatibility at policy setup time.

### Storage Griefing

Malicious actors could create estates naming a victim as beneficiary, attempting to exhaust storage slots. The reference implementation limits inherited tokens to 8 per address (`MAX_INHERITED_TOKENS`). Implementations MUST include griefing protection through storage limits, access control on beneficiary designation, or other mechanisms.

### Key Compromise

If an attacker gains access to the wallet holding a succession-controlled NFT, they control all linked accounts. Unlike standard ERC-721 tokens, the NFT cannot be stolen via `approve()` or `transferFrom()` since only the authorized registry can transfer it. The attack vector is wallet/key compromise, not NFT theft.

Users should store Controller NFTs in hardware wallets, consider multisig custody for high-value estates, and check in regularly to prove continued legitimate control.

### Unclaimed Succession

If a beneficiary becomes inactive before claiming, their designated successor cannot access the original estate. The reference implementation restricts execution to the designated beneficiary only. This prevents unwanted succession (tax liabilities, legal exposure) but creates unclaimed succession risk.

Mitigations include choosing beneficiaries with life expectancy overlap, updating beneficiaries, and maintaining parallel legal planning for multi-generational scenarios.

### Legal Disclaimer

This standard provides technical infrastructure only. Smart contract succession does not replace legal requirements for estate planning. Users should consult qualified professionals regarding wills, trusts, tax implications, and regulatory compliance. Technical ability to transfer control does not guarantee legal recognition.

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).