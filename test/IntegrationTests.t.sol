// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseTest.t.sol";

contract IntegrationTest is BaseTest {

    function test_FullLifecycle_CreateConfigureExecute() public {
        vm.prank(alice);
        (uint256 tokenId, address registry, ) = factory.createEstate();

        vm.prank(alice);
        SimpleSuccessionRegistry(registry).setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        assertEq(controllerNFT.ownerOf(tokenId), alice);
        assertFalse(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));

        vm.warp(block.timestamp + 181 days);

        assertTrue(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));

        vm.prank(bob);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);

        assertEq(controllerNFT.ownerOf(tokenId), bob);
        assertEq(controllerNFT.getCurrentController(alice), bob);
    }

    function test_ChainedInheritance_ThreeGenerations() public {
        vm.prank(alice);
        (uint256 tokenId, address aliceRegistry, ) = factory.createEstate();

        vm.prank(alice);
        SimpleSuccessionRegistry(aliceRegistry).setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        vm.prank(bob);
        SimpleSuccessionRegistry(aliceRegistry).executeSuccession(alice);

        assertEq(controllerNFT.ownerOf(tokenId), bob);

        vm.prank(bob);
        (, address bobRegistry, ) = factory.createEstate();

        vm.prank(bob);
        SimpleSuccessionRegistry(bobRegistry).setupPolicy(charlie, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        skip(181 days);

        vm.prank(charlie);
        SimpleSuccessionRegistry(bobRegistry).executeSuccession(bob);

        uint256[] memory charlieTokens = controllerNFT.getUserOwnedTokens(charlie);
        assertEq(charlieTokens.length, 2);
        assertEq(controllerNFT.getCurrentController(alice), charlie);
        assertEq(controllerNFT.getCurrentController(bob), charlie);
    }

    function test_CheckInPreventsSuccession() public {
        vm.prank(alice);
        (, address registry, ) = factory.createEstate();

        vm.prank(alice);
        SimpleSuccessionRegistry(registry).setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 170 days);

        vm.prank(alice);
        SimpleSuccessionRegistry(registry).checkIn();

        vm.warp(block.timestamp + 170 days);

        assertFalse(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));

        vm.prank(bob);
        vm.expectRevert(SimpleSuccessionRegistry.ConditionsNotMet.selector);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);
    }

    function test_ConcurrentEstates_IndependentTimers() public {
        vm.prank(alice);
        (, address aliceRegistry, ) = factory.createEstate();

        vm.prank(bob);
        (, address bobRegistry, ) = factory.createEstate();

        vm.prank(alice);
        SimpleSuccessionRegistry(aliceRegistry).setupPolicy(charlie, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.prank(bob);
        SimpleSuccessionRegistry(bobRegistry).setupPolicy(charlie, SimpleSuccessionRegistry.WaitPeriod.ONE_YEAR);

        vm.warp(block.timestamp + 181 days);

        assertTrue(SimpleSuccessionRegistry(aliceRegistry).isSuccessionOpen(alice));
        assertFalse(SimpleSuccessionRegistry(bobRegistry).isSuccessionOpen(bob));

        vm.prank(charlie);
        SimpleSuccessionRegistry(aliceRegistry).executeSuccession(alice);

        vm.prank(charlie);
        vm.expectRevert(SimpleSuccessionRegistry.ConditionsNotMet.selector);
        SimpleSuccessionRegistry(bobRegistry).executeSuccession(bob);

        vm.warp(block.timestamp + 185 days);

        vm.prank(charlie);
        SimpleSuccessionRegistry(bobRegistry).executeSuccession(bob);

        uint256[] memory charlieTokens = controllerNFT.getUserOwnedTokens(charlie);
        assertEq(charlieTokens.length, 2);
    }

    function test_RegistryIsolation_SeparateOwners() public {
        vm.prank(alice);
        (, address aliceRegistry, ) = factory.createEstate();

        vm.prank(bob);
        (, address bobRegistry, ) = factory.createEstate();

        assertEq(SimpleSuccessionRegistry(aliceRegistry).owner(), alice);
        assertEq(SimpleSuccessionRegistry(bobRegistry).owner(), bob);

        vm.prank(bob);
        vm.expectRevert();
        SimpleSuccessionRegistry(aliceRegistry).setupPolicy(charlie, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.prank(alice);
        vm.expectRevert();
        SimpleSuccessionRegistry(bobRegistry).setupPolicy(charlie, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);
    }

    function test_OneYearWaitPeriod_FullCycle() public {
        vm.prank(alice);
        (uint256 tokenId, address registry, ) = factory.createEstate();

        vm.prank(alice);
        SimpleSuccessionRegistry(registry).setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.ONE_YEAR);

        vm.warp(block.timestamp + 364 days);
        assertFalse(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));

        vm.warp(block.timestamp + 2 days);
        assertTrue(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));

        vm.prank(bob);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);

        assertEq(controllerNFT.ownerOf(tokenId), bob);
    }
}