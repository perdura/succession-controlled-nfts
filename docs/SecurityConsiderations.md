# Security Considerations

> **Status:** Draft - January 2026

I've tried to think through the major security implications of this standard, covering attack vectors at both the standard level and the reference implementation level. This analysis looks at what ALL implementations need to handle and the specific choices made in the reference.

I'm particularly interested in feedback on:

- Attack vectors I haven't considered
- Whether the MAX_INHERITED_TOKENS = 8 limit makes sense
- The tradeoffs in restricting executeSuccession to beneficiary-only
- Any concerns about the time-based model

If sections are unclear or you think I'm missing something obvious, please call it out.

---

## Threat Model

### Actors

**Owner:** Mints the Controller NFT, deploys registry, sets succession policy. Threats include key compromise, coercion, incapacitation, death.

**Beneficiary:** Designated to receive control when succession conditions are met. Threats include impatience, compromise, unavailability.

**Attacker:** Wants to steal assets or disrupt succession. Standard web3 attack vectors apply.

### Assets at Risk

All assets held in ERC-6551 token-bound accounts linked to the Controller NFT: ETH, ERC-20, ERC-721, ERC-1155 tokens, DeFi positions.

### Trust Boundaries

**Trustless:** Smart contract execution, on-chain succession logic, NFT ownership verification.

**Trust Required:** Beneficiary selection, factory deployer (if using factories), registry implementation correctness. Users must also trust that the ControllerNFT owner has authorized only legitimate factories.

---

## Audit Status

This reference implementation has not been formally audited. Production deployments should undergo independent security audits before use. The interfaces and implementation patterns have been tested (84 tests passing) but have not been reviewed by third-party auditors.

Implementations using this standard should be audited independently regardless of the reference implementation's audit status.

---

## Standard-Level Security

These considerations apply to ALL implementations of IERC721SuccessionControlled and ISuccessionRegistry.

### Registry Centralization

Deploy separate registry instances per subject (one registry per user). Multi-subject registries where a single contract manages succession for multiple users create centralization risks: a vulnerability affects all users, and concentrated value creates honeypot incentives for attackers.

The reference uses EIP-1167 minimal proxies for gas-efficient per-user deployment (~260k gas).

### Immutable Registry Authorization

Once a succession registry is authorized for a user, it cannot be changed in ControllerNFT. Mutable authorization creates social engineering attack vectors where users could be tricked into authorizing malicious registries.

The beneficiary address can still be updated within the registry via `updateBeneficiary()`.

Other implementations could support revocable authorization with appropriate DoS protections (rate limits, cooldowns).

### Beneficiary Contract Compatibility

If the beneficiary is a smart contract, it MUST implement `IERC721Receiver` or succession will revert. Compatible contracts include Gnosis Safe, ERC-4337 smart wallets, and any contract implementing the ERC-721 receiver interface.

Setting an incompatible contract as beneficiary will permanently lock the estate.

### Storage Griefing

Malicious actors could create estates naming a victim as beneficiary, attempting to exhaust storage slots and block legitimate succession.

SimpleSuccessionRegistry handles this through:

- Storage limits: MAX_INHERITED_TOKENS = 8 per address
- Pull pattern: only the beneficiary can call executeSuccession()
- Burn function: beneficiaries can burn unwanted inherited tokens to clear space

**Gas analysis for MAX_INHERITED_TOKENS = 8:**

| Transfer Count | Gas Cost | Block Limit % |
|----------------|----------|---------------|
| 1 token | ~123k | 0.21% |
| 8 tokens (max) | ~442k | 0.74% |

Worst-case remains under 1% of block gas limit (60M).

Implementations MUST include griefing protection. Other approaches include access control on beneficiary designation, off-chain indexing, or different storage limits with documented rationale.

### Unclaimed Succession

If a beneficiary becomes inactive before claiming, their designated successor cannot access the original estate.

**Scenario:**
```
Alice (owner) -> Bob (beneficiary) -> Charlie (Bob's beneficiary)

1. Alice becomes inactive
2. Bob delays claiming
3. Bob becomes inactive
4. Charlie claims Bob's estate
5. Alice's estate remains permanently unclaimed
```

SimpleSuccessionRegistry restricts executeSuccession() to the designated beneficiary only. This protects beneficiaries from unwanted succession (tax liabilities, sanctioned assets, litigation exposure) but creates unclaimed succession risk.

Users should choose beneficiaries with life expectancy overlap and maintain parallel legal planning for multi-generational scenarios.

Implementations could also support contingent beneficiaries or permissionless claiming after extended periods.

---

## Reference Implementation Security

These considerations are specific to ControllerNFT, SimpleSuccessionRegistry, and EstateFactory.

### Factory Trust Model

EstateFactory is a trusted deployer that can mint NFTs and authorize registries. The ControllerNFT owner controls which factories are trusted via `setTrustedFactory()`.

For production deployments, transfer factory ownership to governance or multisig. Users should verify factory and implementation code before use. Multiple competing factories can coexist.

### Reentrancy Protection

All state-changing functions use OpenZeppelin's ReentrancyGuard:

- EstateFactory.createEstate()
- SimpleSuccessionRegistry.executeSuccession()

The registry holds no assets, limiting reentrancy impact, but the guards provide an extra layer of protection.

### Clone Initialization

Clones use factory-only initialization to prevent front-running:
```solidity
function initialize(address _owner, address _controllerNFT, address _factory) external initializer {
    if (msg.sender != _factory) revert NotFactory();
    // ...
}
```

Implementation contracts call `_disableInitializers()` in constructor to prevent direct initialization.

### Time Manipulation

Block timestamps can be manipulated by validators within consensus bounds (~15 seconds). With 6-month or 1-year wait periods, this manipulation window is negligible.

Short wait periods (hours/days) would be more vulnerable. SimpleSuccessionRegistry enforces minimum periods of 180 days.

### Original Token Protection

Users cannot burn their originally minted Controller NFT. This prevents permanent asset lockout where `getCurrentController()` would return `address(0)`.

Inherited tokens CAN be burned to clear storage space for future successions.

---

## Key Compromise

If an attacker gains access to the wallet holding a Controller NFT, they control all linked token-bound accounts. They can also call registry functions: `checkIn()`, `updateBeneficiary()`.

Unlike standard ERC-721 tokens, the NFT cannot be stolen via `approve()` or `transferFrom()`. These functions revert when a registry is authorized. The attack vector is wallet/key compromise, not NFT theft.

To reduce this risk:

- Store Controller NFTs in hardware wallets
- Use multisig custody for high-value estates
- Check in regularly to prove continued legitimate control
- Use separate wallets for Controller NFT vs daily transactions

---

## Privacy Considerations

**On-chain (public):** Controller NFT ownership, registry address, beneficiary address, check-in timestamps, succession events, TBA addresses and contents.

**Off-chain (private):** Real-world identity of owner and beneficiary (if using fresh addresses), relationship between parties.

Succession planning inherently creates on-chain records linking addresses. Users requiring privacy should use dedicated addresses not linked to other activity.

Future implementations could use commit-reveal schemes for beneficiary addresses or zero-knowledge proofs for activity verification. These extensions are compatible with the minimal spec interfaces.

---

## Legal Disclaimer

This standard provides technical infrastructure only. Smart contract succession does not replace legal requirements for estate planning.

Technical transfer of digital asset control may not be recognized in probate courts, corporate governance proceedings, bankruptcy proceedings, or regulatory enforcement actions.

Users MUST:

- Consult qualified legal professionals
- Maintain traditional legal documentation (wills, trusts)
- Understand tax implications in relevant jurisdictions
- Comply with applicable regulations

The technical ability to transfer control does not guarantee legal recognition.

---

## Security Disclosure

For responsible disclosure of vulnerabilities, use [GitHub Security Advisories](https://github.com/perdura/succession-controlled-nfts/security/advisories/new).

Do not open public issues for security vulnerabilities.

---

**Last Updated:** January 2026