// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseTest.t.sol";

contract ControllerNFTTest is BaseTest {
    function test_MintFirstNFT() public {
        vm.startPrank(alice);

        vm.expectEmit(true, true, false, true);
        emit ControllerNFT.ControllerNFTMinted(alice, 1);

        controllerNFT.mint();

        assertEq(controllerNFT.ownerOf(1), alice);
        assertTrue(controllerNFT.hasMinted(alice));
        assertEq(controllerNFT.originalTokenId(alice), 1);
        assertEq(controllerNFT.totalMinted(), 1);

        vm.stopPrank();
    }

    function test_RevertWhen_MintingTwice() public {
        vm.startPrank(alice);
        controllerNFT.mint();

        vm.expectRevert(ControllerNFT.AlreadyMinted.selector);
        controllerNFT.mint();

        vm.stopPrank();
    }

    function test_MintMultipleUsers() public {
        vm.prank(alice);
        controllerNFT.mint();

        vm.prank(bob);
        controllerNFT.mint();

        vm.prank(charlie);
        controllerNFT.mint();

        assertEq(controllerNFT.totalMinted(), 3);
        assertTrue(controllerNFT.hasMinted(alice));
        assertTrue(controllerNFT.hasMinted(bob));
        assertTrue(controllerNFT.hasMinted(charlie));
    }

    function test_MintFor_ByTrustedFactory() public {
        vm.prank(address(factory));
        uint256 tokenId = controllerNFT.mintFor(alice);

        assertEq(tokenId, 1);
        assertEq(controllerNFT.ownerOf(1), alice);
        assertTrue(controllerNFT.hasMinted(alice));
    }

    function test_RevertWhen_MintFor_UntrustedCaller() public {
        vm.prank(attacker);
        vm.expectRevert(ControllerNFT.NotTrustedFactory.selector);
        controllerNFT.mintFor(alice);
    }

    function test_RevertWhen_TransferringNormally() public {
        vm.prank(alice);
        controllerNFT.mint();
        uint256 tokenId = controllerNFT.originalTokenId(alice);

        vm.startPrank(alice);

        vm.expectRevert(ControllerNFT.RegistryOnly.selector);
        controllerNFT.transferFrom(alice, bob, tokenId);

        vm.expectRevert(ControllerNFT.RegistryOnly.selector);
        controllerNFT.safeTransferFrom(alice, bob, tokenId);

        vm.expectRevert(ControllerNFT.RegistryOnly.selector);
        controllerNFT.safeTransferFrom(alice, bob, tokenId, "");

        vm.stopPrank();
    }

    function test_RevertWhen_AttackerTransfersNFT() public {
        vm.prank(alice);
        (uint256 tokenId,,) = factory.createEstate();

        vm.prank(attacker);
        vm.expectRevert();
        controllerNFT.transferFrom(alice, attacker, tokenId);
    }

    function test_RevertWhen_ApprovingNFT() public {
        vm.prank(alice);
        controllerNFT.mint();
        uint256 tokenId = controllerNFT.originalTokenId(alice);

        vm.startPrank(alice);

        vm.expectRevert(ControllerNFT.RegistryOnly.selector);
        controllerNFT.approve(bob, tokenId);

        vm.expectRevert(ControllerNFT.RegistryOnly.selector);
        controllerNFT.setApprovalForAll(bob, true);

        vm.stopPrank();
    }

    function test_RegistryAuthorization_ViaFactory() public {
        vm.prank(alice);
        (uint256 tokenId, address registry,) = factory.createEstate();

        assertEq(controllerNFT.successionRegistryOf(alice), registry);
        assertEq(controllerNFT.ownerOf(tokenId), alice);
    }

    function test_RevertWhen_UnauthorizedFactoryAuthorizes() public {
        address fakeFactory = makeAddr("fakeFactory");
        address fakeRegistry = makeAddr("fakeRegistry");

        vm.prank(alice);
        controllerNFT.mint();

        vm.prank(fakeFactory);
        vm.expectRevert(ControllerNFT.NotTrustedFactory.selector);
        controllerNFT.authorizeRegistry(alice, fakeRegistry);
    }

    function test_RevertWhen_AttackerAuthorizesRegistry() public {
        vm.prank(alice);
        controllerNFT.mint();

        address fakeRegistry = makeAddr("fakeRegistry");

        vm.prank(attacker);
        vm.expectRevert(ControllerNFT.NotTrustedFactory.selector);
        controllerNFT.authorizeRegistry(alice, fakeRegistry);
    }

    function test_RevertWhen_AuthorizingSecondRegistry() public {
        vm.prank(alice);
        factory.createEstate();

        address secondRegistry = makeAddr("secondRegistry");

        vm.prank(address(factory));
        vm.expectRevert(ControllerNFT.RegistryAlreadySet.selector);
        controllerNFT.authorizeRegistry(alice, secondRegistry);
    }

    function test_GetCurrentController_NormalCase() public {
        vm.prank(alice);
        factory.createEstate();

        assertEq(controllerNFT.getCurrentController(alice), alice);
    }

    function test_GetCurrentController_AfterSuccession() public {
        vm.prank(alice);
        (, address registry,) = factory.createEstate();

        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        vm.prank(bob);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);

        assertEq(controllerNFT.getCurrentController(alice), bob);
    }

    function test_GetCurrentController_NeverMinted() public view {
        assertEq(controllerNFT.getCurrentController(alice), address(0));
    }

    function test_RevertWhen_BurningOriginalToken() public {
        vm.prank(alice);
        factory.createEstate();
        uint256 tokenId = controllerNFT.originalTokenId(alice);

        vm.prank(alice);
        vm.expectRevert(ControllerNFT.CannotBurnOriginalToken.selector);
        controllerNFT.burn(tokenId);

        assertEq(controllerNFT.ownerOf(tokenId), alice);
    }

    function test_RevertWhen_BurningOthersToken() public {
        vm.prank(alice);
        factory.createEstate();
        uint256 tokenId = controllerNFT.originalTokenId(alice);

        vm.prank(bob);
        vm.expectRevert(ControllerNFT.NotAuthorized.selector);
        controllerNFT.burn(tokenId);
    }

    function test_BurnInheritedToken() public {
        vm.prank(alice);
        (, address registry,) = factory.createEstate();

        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        vm.prank(bob);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);

        uint256 aliceTokenId = controllerNFT.originalTokenId(alice);

        vm.prank(bob);
        controllerNFT.burn(aliceTokenId);

        vm.expectRevert();
        controllerNFT.ownerOf(aliceTokenId);
    }

    function test_InheritanceLimit_MaxTokens() public {
        uint256 maxTokens = controllerNFT.MAX_INHERITED_TOKENS();

        vm.prank(bob);
        factory.createEstate();

        address[] memory users = new address[](maxTokens);
        address[] memory registries = new address[](maxTokens);

        for (uint256 i = 0; i < maxTokens; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            vm.deal(users[i], 10 ether);

            vm.prank(users[i]);
            (, registries[i],) = factory.createEstate();

            vm.prank(users[i]);
            SimpleSuccessionRegistry(registries[i])
                .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);
        }

        vm.warp(block.timestamp + 181 days);

        for (uint256 i = 0; i < maxTokens - 1; i++) {
            vm.prank(bob);
            SimpleSuccessionRegistry(registries[i]).executeSuccession(users[i]);
        }

        uint256 bobTokens = controllerNFT.getUserOwnedTokens(bob).length;
        assertEq(bobTokens, 8);

        vm.prank(bob);
        vm.expectRevert();
        SimpleSuccessionRegistry(registries[maxTokens - 1]).executeSuccession(users[maxTokens - 1]);
    }

    function test_SetTrustedFactory() public {
        address newFactory = makeAddr("newFactory");

        vm.prank(deployer);
        controllerNFT.setTrustedFactory(newFactory, true);

        assertTrue(controllerNFT.isTrustedFactory(newFactory));

        vm.prank(deployer);
        controllerNFT.setTrustedFactory(newFactory, false);

        assertFalse(controllerNFT.isTrustedFactory(newFactory));
    }

    function test_RevertWhen_NonOwnerSetsTrustedFactory() public {
        address newFactory = makeAddr("newFactory");

        vm.prank(alice);
        vm.expectRevert();
        controllerNFT.setTrustedFactory(newFactory, true);
    }

    function test_GetUserOwnedTokens_Single() public {
        vm.prank(alice);
        factory.createEstate();

        uint256[] memory tokens = controllerNFT.getUserOwnedTokens(alice);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], 1);
    }

    function test_GetUserOwnedTokens_Multiple() public {
        vm.prank(alice);
        factory.createEstate();

        vm.prank(bob);
        (, address bobRegistry,) = factory.createEstate();

        vm.prank(bob);
        SimpleSuccessionRegistry(bobRegistry)
            .setupPolicy(alice, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        vm.prank(alice);
        SimpleSuccessionRegistry(bobRegistry).executeSuccession(bob);

        uint256[] memory tokens = controllerNFT.getUserOwnedTokens(alice);
        assertEq(tokens.length, 2);
    }

    function test_TotalMinted_Increments() public {
        assertEq(controllerNFT.totalMinted(), 0);

        vm.prank(alice);
        factory.createEstate();
        assertEq(controllerNFT.totalMinted(), 1);

        vm.prank(bob);
        factory.createEstate();
        assertEq(controllerNFT.totalMinted(), 2);
    }

    function test_OriginalTokenId_ZeroWhenNotMinted() public view {
        assertEq(controllerNFT.originalTokenId(alice), 0);
        assertFalse(controllerNFT.hasMinted(alice));
    }
}
