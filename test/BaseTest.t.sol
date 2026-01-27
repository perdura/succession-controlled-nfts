// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/interfaces/ISuccessionRegistry.sol";
import "../contracts/interfaces/IERC721SuccessionControlled.sol";
import "../contracts/reference/ControllerNFT.sol";
import "../contracts/reference/SimpleSuccessionRegistry.sol";
import "../contracts/reference/EstateFactory.sol";

abstract contract BaseTest is Test {
    ControllerNFT public controllerNFT;
    SimpleSuccessionRegistry public registryImpl;
    EstateFactory public factory;

    address public deployer;
    address public alice;
    address public bob;
    address public charlie;
    address public david;
    address public eve;
    address public attacker;

    address constant ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    address constant ERC6551_ACCOUNT_IMPL = 0x55266d75D1a14E4572138116aF39863Ed6596E7F;

    function setUp() public virtual {
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        david = makeAddr("david");
        eve = makeAddr("eve");
        attacker = makeAddr("attacker");

        vm.deal(deployer, 1000 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(david, 100 ether);
        vm.deal(eve, 100 ether);
        vm.deal(attacker, 100 ether);

        // Deploy mock at canonical 6551 registry address
        vm.etch(ERC6551_REGISTRY, type(Mock6551Registry).runtimeCode);

        vm.startPrank(deployer);

        controllerNFT = new ControllerNFT();
        registryImpl = new SimpleSuccessionRegistry();

        factory = new EstateFactory(
            address(controllerNFT), address(registryImpl), ERC6551_REGISTRY, ERC6551_ACCOUNT_IMPL
        );

        controllerNFT.setTrustedFactory(address(factory), true);

        vm.stopPrank();

        vm.warp(1 days);
    }
}

/// @dev Minimal mock so EstateFactory.createEstate() doesn't revert
contract Mock6551Registry {
    uint256 private _nonce;

    function createAccount(address, bytes32, uint256, address, uint256) external returns (address) {
        _nonce++;
        return address(uint160(uint256(keccak256(abi.encode(_nonce)))));
    }
}
