// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/reference/ControllerNFT.sol";
import "../contracts/reference/SimpleSuccessionRegistry.sol";
import "../contracts/reference/EstateFactory.sol";

/// @title Interact
/// @notice Create an estate and configure succession policy on existing deployment
/// @dev Usage:
///      1. Set environment variables (see below)
///      2. source .env
///      3. forge script script/Interact.s.sol --rpc-url $RPC_URL --broadcast
///
///      Required env vars:
///        PRIVATE_KEY     - Your wallet private key
///        FACTORY         - Deployed EstateFactory address
///        BENEFICIARY     - Address to receive estate on succession
///
///      Optional env vars:
///        WAIT_PERIOD     - 0 for 6 months, 1 for 1 year (default: 0)
contract Interact is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address factoryAddr = vm.envAddress("FACTORY");
        address beneficiary = vm.envAddress("BENEFICIARY");
        
        // Default to 6 months if not specified
        uint8 waitPeriod = uint8(vm.envOr("WAIT_PERIOD", uint256(0)));
        
        console.log("=== Estate Creation ===");
        console.log("Deployer:", deployer);
        console.log("Factory:", factoryAddr);
        console.log("Beneficiary:", beneficiary);
        console.log("Wait Period:", waitPeriod == 0 ? "6 months" : "1 year");
        console.log("");

        EstateFactory factory = EstateFactory(factoryAddr);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Create estate (NFT + Registry + TBA)
        (uint256 tokenId, address registry, address tba) = factory.createEstate();
        
        console.log("Estate created:");
        console.log("  Token ID:", tokenId);
        console.log("  Registry:", registry);
        console.log("  TBA:", tba);

        // 2. Configure succession policy
        SimpleSuccessionRegistry(registry).setupPolicy(
            beneficiary,
            SimpleSuccessionRegistry.WaitPeriod(waitPeriod)
        );
        
        console.log("");
        console.log("Policy configured:");
        console.log("  Beneficiary:", beneficiary);
        console.log("  Wait Period:", waitPeriod == 0 ? "6 months" : "1 year");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Complete ===");
        console.log("Your estate is now active. Check in periodically to reset the succession timer.");
        console.log("");
        console.log("To check in, run:");
        console.log("  cast send", registry, '"checkIn()" --rpc-url $RPC_URL --private-key $PRIVATE_KEY');
    }
}