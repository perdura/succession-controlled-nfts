# Testnet Deployment

Live deployment on Sepolia for testing and review.

## Network

- **Network:** Sepolia
- **Chain ID:** 11155111
- **Block Explorer:** https://sepolia.etherscan.io

## Core Contracts

| Contract | Address |
|----------|---------|
| ControllerNFT | [`0xa91893bAa83cF7d602626B1eFaEfc42046AA2B0F`](https://sepolia.etherscan.io/address/0xa91893bAa83cF7d602626B1eFaEfc42046AA2B0F) |
| SimpleSuccessionRegistry (impl) | [`0xc66146D36c5D7b66BC76E00Cf19E2ad1079f29f3`](https://sepolia.etherscan.io/address/0xc66146D36c5D7b66BC76E00Cf19E2ad1079f29f3) |
| EstateFactory | [`0x10060a89F908f222227df3C781E8f03577dCeA90`](https://sepolia.etherscan.io/address/0x10060a89F908f222227df3C781E8f03577dCeA90) |

## External Dependencies

| Contract | Address |
|----------|---------|
| ERC-6551 Registry | [`0x000000006551c19487814612e58FE06813775758`](https://sepolia.etherscan.io/address/0x000000006551c19487814612e58FE06813775758) |
| ERC-6551 Account Implementation | [`0x55266d75D1a14E4572138116aF39863Ed6596E7F`](https://sepolia.etherscan.io/address/0x55266d75D1a14E4572138116aF39863Ed6596E7F) |

## Example Estate

A configured estate demonstrating the full lifecycle:

| Component | Address/Value |
|-----------|---------------|
| Owner | `0x4c54848D50C3e6B9FB6f7cCBB34C385EDee53fF0` |
| Token ID | 1 |
| Registry Clone | [`0x67b9859D5744b8D528fcf075c240af3341d43a0a`](https://sepolia.etherscan.io/address/0x67b9859D5744b8D528fcf075c240af3341d43a0a) |
| Token Bound Account | [`0xaade55642F6E42f9340d316660F76775464CEa80`](https://sepolia.etherscan.io/address/0xaade55642F6E42f9340d316660F76775464CEa80) |
| Beneficiary | `0xFe975C50d7e75827F9d4F1F6a57ecf3791ef7fb5` |
| Wait Period | 6 months |
| TBA Balance | 0.01 ETH |

## Try It Yourself

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Sepolia ETH ([faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia))

### Setup
```bash
git clone https://github.com/perdura/succession-controlled-nfts
cd succession-controlled-nfts
forge install
```

Create `.env`:
```
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
RPC_URL=https://rpc.sepolia.org
FACTORY=0x10060a89F908f222227df3C781E8f03577dCeA90
BENEFICIARY=0xYOUR_BENEFICIARY_ADDRESS
WAIT_PERIOD=0
```

### Create Your Own Estate
```bash
source .env
forge script script/Interact.s.sol --rpc-url $RPC_URL --broadcast
```

### Query Estate Status
```bash
# Check if succession is open
cast call 0x67b9859D5744b8D528fcf075c240af3341d43a0a "isSuccessionOpen(address)" 0x4c54848D50C3e6B9FB6f7cCBB34C385EDee53fF0 --rpc-url $RPC_URL

# Get policy details
cast call 0x67b9859D5744b8D528fcf075c240af3341d43a0a "getStatus()" --rpc-url $RPC_URL

# Check TBA balance
cast balance 0xaade55642F6E42f9340d316660F76775464CEa80 --rpc-url $RPC_URL
```

### Check In (Reset Wait Period)
```bash
cast send YOUR_REGISTRY_ADDRESS "checkIn()" --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Deployment Transactions

| Transaction | Hash |
|-------------|------|
| Deploy ControllerNFT | [`0x4c3a57511056c29c75f0e0b11589c65024bb85dcea6714a9461132abccd66cb7`](https://sepolia.etherscan.io/tx/0x4c3a57511056c29c75f0e0b11589c65024bb85dcea6714a9461132abccd66cb7) |
| Deploy SimpleSuccessionRegistry | [`0xc0dc3e2a1175c6e1620d95377448eb6cf5fde4b97559d6afbbb6a98fa4808607`](https://sepolia.etherscan.io/tx/0xc0dc3e2a1175c6e1620d95377448eb6cf5fde4b97559d6afbbb6a98fa4808607) |
| Deploy EstateFactory | [`0xcd207d24a4cef7be04bcbfe68b17d78fb9a850a426e30e879218678d8fe90683`](https://sepolia.etherscan.io/tx/0xcd207d24a4cef7be04bcbfe68b17d78fb9a850a426e30e879218678d8fe90683) |
| Set Trusted Factory | [`0xc89c897dca8c3604ea5ce66c70c97d57c678aa47e6fa89873a0dccfb92eb91ee`](https://sepolia.etherscan.io/tx/0xc89c897dca8c3604ea5ce66c70c97d57c678aa47e6fa89873a0dccfb92eb91ee) |
| Create Example Estate | [`0xb2b9a5e241a046339166878597ebd4fc8e18d7c1b7d28933925d76af8fdac16f`](https://sepolia.etherscan.io/tx/0xb2b9a5e241a046339166878597ebd4fc8e18d7c1b7d28933925d76af8fdac16f) |
| Setup Policy | [`0xf3537785d850a9933aeb074f62861323bbba04ca36dd7b34c61660477e681d9b`](https://sepolia.etherscan.io/tx/0xf3537785d850a9933aeb074f62861323bbba04ca36dd7b34c61660477e681d9b) |
| Fund TBA | [`0x839b3b4c530553e9e5d0697f648fed64af8819c7ad2074ca0484eb4ebf9b7517`](https://sepolia.etherscan.io/tx/0x839b3b4c530553e9e5d0697f648fed64af8819c7ad2074ca0484eb4ebf9b7517) |

---

Deployed January 2026