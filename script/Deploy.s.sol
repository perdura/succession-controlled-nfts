// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/reference/ControllerNFT.sol";
import "../contracts/reference/SimpleSuccessionRegistry.sol";
import "../contracts/reference/EstateFactory.sol";

/// @title Deploy
/// @notice Deploys the full succession-controlled NFT stack
/// @dev Usage:
///      1. Copy .env.example to .env and fill in values
///      2. source .env
///      3. forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
///
///      Note: Requires ERC-6551 registry at 0x000000006551c19487814612e58FE06813775758
///      This is deployed on mainnet, Sepolia, Optimism, Arbitrum, Base, Polygon, etc.
///      For local testing, fork a chain that has it or use the test suite instead.
contract Deploy is Script {
    // Canonical ERC-6551 registry (same on all chains)
    address constant ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;

    // Reference ERC-6551 account implementation
    address constant ERC6551_ACCOUNT_IMPL = 0x55266d75D1a14E4572138116aF39863Ed6596E7F;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ControllerNFT
        ControllerNFT controllerNFT = new ControllerNFT();
        console.log("ControllerNFT:", address(controllerNFT));

        // 2. Deploy SimpleSuccessionRegistry implementation
        SimpleSuccessionRegistry registryImpl = new SimpleSuccessionRegistry();
        console.log("SimpleSuccessionRegistry (impl):", address(registryImpl));

        // 3. Deploy EstateFactory
        EstateFactory factory = new EstateFactory(
            address(controllerNFT), address(registryImpl), ERC6551_REGISTRY, ERC6551_ACCOUNT_IMPL
        );
        console.log("EstateFactory:", address(factory));

        // 4. Set factory as trusted
        controllerNFT.setTrustedFactory(address(factory), true);
        console.log("");
        console.log("Factory set as trusted");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("ControllerNFT:", address(controllerNFT));
        console.log("SimpleSuccessionRegistry (impl):", address(registryImpl));
        console.log("EstateFactory:", address(factory));
    }
}
