# Testnet Deployment

Live deployment on Sepolia for testing and review.

## Network

- **Network:** Sepolia
- **Chain ID:** 11155111
- **Block Explorer:** https://sepolia.etherscan.io

## Core Contracts

| Contract | Address |
|----------|---------|
| ControllerNFT | [`0x8dC1f19E3cc8039601f770454249Eda265fcA783`](https://sepolia.etherscan.io/address/0x8dC1f19E3cc8039601f770454249Eda265fcA783) |
| SimpleSuccessionRegistry (impl) | [`0xe5530DDf9169B9c6a267a07e41549dC5614e8Fa2`](https://sepolia.etherscan.io/address/0xe5530DDf9169B9c6a267a07e41549dC5614e8Fa2) |
| EstateFactory | [`0x92F310D9DAA7170D243381abFa96B1f4EE5e73A3`](https://sepolia.etherscan.io/address/0x92F310D9DAA7170D243381abFa96B1f4EE5e73A3) |

## External Dependencies

| Contract | Address |
|----------|---------|
| ERC-6551 Registry | [`0x000000006551c19487814612e58FE06813775758`](https://sepolia.etherscan.io/address/0x000000006551c19487814612e58FE06813775758) |
| ERC-6551 Account Implementation | [`0x55266d75D1a14E4572138116aF39863Ed6596E7F`](https://sepolia.etherscan.io/address/0x55266d75D1a14E4572138116aF39863Ed6596E7F) |

## Example Estate

A configured estate demonstrating the full lifecycle:

| Component | Address/Value |
|-----------|---------------|
| Owner | `0xa369912c0A4C8c2338415B108f975D0446CB66Bd` |
| Token ID | 1 |
| Registry Clone | [`0xDBed51dCb44229CD1497809c04F0956845506cCa`](https://sepolia.etherscan.io/address/0xDBed51dCb44229CD1497809c04F0956845506cCa) |
| Token Bound Account | [`0x4a4CeEaC967FE2cD1Ce5fEcD9c068AdE3180D6c6`](https://sepolia.etherscan.io/address/0x4a4CeEaC967FE2cD1Ce5fEcD9c068AdE3180D6c6) |
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
FACTORY=0x92F310D9DAA7170D243381abFa96B1f4EE5e73A3
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
cast call 0xDBed51dCb44229CD1497809c04F0956845506cCa "isSuccessionOpen(address)" 0xa369912c0A4C8c2338415B108f975D0446CB66Bd --rpc-url $RPC_URL

# Get policy details
cast call 0xDBed51dCb44229CD1497809c04F0956845506cCa "getStatus()" --rpc-url $RPC_URL

# Check TBA balance
cast balance 0x4a4CeEaC967FE2cD1Ce5fEcD9c068AdE3180D6c6 --rpc-url $RPC_URL
```

### Check In (Reset Wait Period)
```bash
cast send YOUR_REGISTRY_ADDRESS "checkIn()" --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Deployment Transactions

| Transaction | Hash |
|-------------|------|
| Deploy ControllerNFT | [`0x860c786d07cbe40fff02f1625363aaa235d7aecc444fb621bdd3af77563b265e`](https://sepolia.etherscan.io/tx/0x860c786d07cbe40fff02f1625363aaa235d7aecc444fb621bdd3af77563b265e) |
| Deploy SimpleSuccessionRegistry | [`0x838007cdc94c682f088feec7bcbabb4c5a8ac4beed252bf590f29ce42f1a085c`](https://sepolia.etherscan.io/tx/0x838007cdc94c682f088feec7bcbabb4c5a8ac4beed252bf590f29ce42f1a085c) |
| Deploy EstateFactory | [`0xcaa23508e8b52a93d699b8bb5a4ad9901cf42d2d1b013902d16998a2190c237b`](https://sepolia.etherscan.io/tx/0xcaa23508e8b52a93d699b8bb5a4ad9901cf42d2d1b013902d16998a2190c237b) |
| Set Trusted Factory | [`0xcf2a85fef2c907ccba5b0c2cca52e8c757531ec758ce97f31b21dfc8b3f53c4d`](https://sepolia.etherscan.io/tx/0xcf2a85fef2c907ccba5b0c2cca52e8c757531ec758ce97f31b21dfc8b3f53c4d) |
| Create Example Estate | [`0x4ebd469a0011a43527bbea754d2ef2184407571ccac59698eadf2f55b27b062a`](https://sepolia.etherscan.io/tx/0x4ebd469a0011a43527bbea754d2ef2184407571ccac59698eadf2f55b27b062a) |
| Setup Policy | [`0xbd9f5758c8ac6c7ee775da453adbb449c0eb7b408918c965c170f9c961f90464`](https://sepolia.etherscan.io/tx/0xbd9f5758c8ac6c7ee775da453adbb449c0eb7b408918c965c170f9c961f90464) |
| Fund TBA | [`0x0d4d8dd183dc5799ae589a04d4ead29723840bd89115a96afeb9e6fc3bc8e01f`](https://sepolia.etherscan.io/tx/0x0d4d8dd183dc5799ae589a04d4ead29723840bd89115a96afeb9e6fc3bc8e01f) |
| Check In | [`0x7ee1794ede213ebe080c01a895f20d9926a7667b227b38e6061a85252f9b45b9`](https://sepolia.etherscan.io/tx/0x7ee1794ede213ebe080c01a895f20d9926a7667b227b38e6061a85252f9b45b9) |

---

Deployed February 2026