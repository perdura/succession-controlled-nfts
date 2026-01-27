// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseTest.t.sol";

contract EstateFactoryTest is BaseTest {
    function test_FactoryImmutables() public view {
        assertEq(address(factory.controllerNFT()), address(controllerNFT));
        assertEq(factory.registryImplementation(), address(registryImpl));
        assertEq(address(factory.erc6551Registry()), ERC6551_REGISTRY);
        assertEq(factory.erc6551AccountImplementation(), ERC6551_ACCOUNT_IMPL);
    }

    function test_RevertWhen_ConstructorZeroControllerNFT() public {
        vm.expectRevert(EstateFactory.ZeroAddress.selector);
        new EstateFactory(address(0), address(registryImpl), ERC6551_REGISTRY, ERC6551_ACCOUNT_IMPL);
    }

    function test_RevertWhen_ConstructorZeroRegistryImpl() public {
        vm.expectRevert(EstateFactory.ZeroAddress.selector);
        new EstateFactory(
            address(controllerNFT), address(0), ERC6551_REGISTRY, ERC6551_ACCOUNT_IMPL
        );
    }

    function test_RevertWhen_ConstructorZero6551Registry() public {
        vm.expectRevert(EstateFactory.ZeroAddress.selector);
        new EstateFactory(
            address(controllerNFT), address(registryImpl), address(0), ERC6551_ACCOUNT_IMPL
        );
    }

    function test_RevertWhen_ConstructorZero6551AccountImpl() public {
        vm.expectRevert(EstateFactory.ZeroAddress.selector);
        new EstateFactory(
            address(controllerNFT), address(registryImpl), ERC6551_REGISTRY, address(0)
        );
    }

    function test_CreateEstate_MintsNFT() public {
        vm.prank(alice);
        (uint256 tokenId,,) = factory.createEstate();

        assertEq(tokenId, 1);
        assertEq(controllerNFT.ownerOf(tokenId), alice);
        assertTrue(controllerNFT.hasMinted(alice));
    }

    function test_CreateEstate_DeploysRegistry() public {
        vm.prank(alice);
        (, address registry,) = factory.createEstate();

        assertTrue(registry != address(0));
        assertEq(SimpleSuccessionRegistry(registry).owner(), alice);
        assertEq(
            address(SimpleSuccessionRegistry(registry).controllerNFT()), address(controllerNFT)
        );
    }

    function test_CreateEstate_AuthorizesRegistry() public {
        vm.prank(alice);
        (, address registry,) = factory.createEstate();

        assertEq(controllerNFT.successionRegistryOf(alice), registry);
    }

    function test_CreateEstate_CreatesTBA() public {
        vm.prank(alice);
        (,, address tba) = factory.createEstate();

        assertTrue(tba != address(0));
    }

    function test_CreateEstate_EmitsEvent() public {
        vm.prank(alice);

        vm.expectEmit(true, true, false, false);
        emit EstateFactory.EstateCreated(alice, 1, address(0), address(0));

        factory.createEstate();
    }

    function test_CreateEstate_MultipleUsers() public {
        vm.prank(alice);
        (uint256 aliceTokenId, address aliceRegistry, address aliceTba) = factory.createEstate();

        vm.prank(bob);
        (uint256 bobTokenId, address bobRegistry, address bobTba) = factory.createEstate();

        vm.prank(charlie);
        (uint256 charlieTokenId, address charlieRegistry, address charlieTba) =
            factory.createEstate();

        assertEq(aliceTokenId, 1);
        assertEq(bobTokenId, 2);
        assertEq(charlieTokenId, 3);

        assertTrue(aliceRegistry != bobRegistry);
        assertTrue(bobRegistry != charlieRegistry);
        assertTrue(aliceRegistry != charlieRegistry);

        assertTrue(aliceTba != bobTba);
        assertTrue(bobTba != charlieTba);
        assertTrue(aliceTba != charlieTba);

        assertEq(controllerNFT.totalMinted(), 3);
    }

    function test_Gas_CreateEstate() public {
        uint256 gasBefore = gasleft();

        vm.prank(alice);
        factory.createEstate();

        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for createEstate", gasUsed);
        assertLt(gasUsed, 500_000);
    }
}
