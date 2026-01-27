// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseTest.t.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract SimpleSuccessionRegistryTest is BaseTest {
    address public registry;

    function setUp() public override {
        super.setUp();

        vm.prank(alice);
        (, registry,) = factory.createEstate();
    }

    function test_RegistryInitialization() public view {
        SimpleSuccessionRegistry reg = SimpleSuccessionRegistry(registry);
        assertEq(reg.owner(), alice);
        assertEq(address(reg.controllerNFT()), address(controllerNFT));
    }

    function test_RevertWhen_InitializingImplementation() public {
        vm.expectRevert();
        registryImpl.initialize(alice, address(controllerNFT), address(factory));
    }

    function test_OnlyFactoryCanInitialize() public {
        address clone = Clones.clone(address(registryImpl));

        vm.prank(address(factory));
        SimpleSuccessionRegistry(clone).initialize(alice, address(controllerNFT), address(factory));

        assertEq(SimpleSuccessionRegistry(clone).owner(), alice);
    }

    function test_RevertWhen_NonFactoryInitializesClone() public {
        address clone = Clones.clone(address(registryImpl));

        vm.prank(attacker);
        vm.expectRevert(SimpleSuccessionRegistry.NotFactory.selector);
        SimpleSuccessionRegistry(clone)
            .initialize(attacker, address(controllerNFT), address(factory));
    }

    function test_RevertWhen_ReinitializingClone() public {
        vm.prank(address(factory));
        vm.expectRevert();
        SimpleSuccessionRegistry(registry).initialize(bob, address(controllerNFT), address(factory));
    }

    function test_SetupPolicy_SixMonths() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        SimpleSuccessionRegistry.Policy memory policy =
            SimpleSuccessionRegistry(registry).getPolicy();
        assertEq(policy.beneficiary, bob);
        assertEq(
            uint256(policy.waitPeriod), uint256(SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS)
        );
        assertTrue(policy.configured);
    }

    function test_SetupPolicy_OneYear() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.ONE_YEAR);

        SimpleSuccessionRegistry.Policy memory policy =
            SimpleSuccessionRegistry(registry).getPolicy();
        assertEq(uint256(policy.waitPeriod), uint256(SimpleSuccessionRegistry.WaitPeriod.ONE_YEAR));
    }

    function test_RevertWhen_AlreadyConfigured() public {
        vm.startPrank(alice);

        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.expectRevert(SimpleSuccessionRegistry.AlreadyConfigured.selector);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(charlie, SimpleSuccessionRegistry.WaitPeriod.ONE_YEAR);

        vm.stopPrank();
    }

    function test_RevertWhen_ZeroBeneficiary() public {
        vm.prank(alice);
        vm.expectRevert(SimpleSuccessionRegistry.ZeroAddress.selector);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(address(0), SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);
    }

    function test_RevertWhen_NonOwnerConfigures() public {
        vm.prank(bob);
        vm.expectRevert();
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);
    }

    function test_CheckIn() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        uint64 initialCheckIn = SimpleSuccessionRegistry(registry).getPolicy().lastCheckIn;

        vm.warp(block.timestamp + 8 days);

        vm.prank(alice);
        SimpleSuccessionRegistry(registry).checkIn();

        uint64 newCheckIn = SimpleSuccessionRegistry(registry).getPolicy().lastCheckIn;
        assertGt(newCheckIn, initialCheckIn);
    }

    function test_CheckInResetsSuccessionTimer() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 179 days);

        vm.prank(bob);
        vm.expectRevert(SimpleSuccessionRegistry.ConditionsNotMet.selector);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);

        vm.prank(alice);
        SimpleSuccessionRegistry(registry).checkIn();

        vm.warp(block.timestamp + 2 days);

        vm.prank(bob);
        vm.expectRevert(SimpleSuccessionRegistry.ConditionsNotMet.selector);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);

        vm.warp(block.timestamp + 180 days);

        vm.prank(bob);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);
        assertEq(controllerNFT.ownerOf(1), bob);
    }

    function test_MultipleCheckIns_ExtendTimer() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        for (uint256 i = 0; i < 5; i++) {
            vm.warp(block.timestamp + 100 days);

            vm.prank(alice);
            SimpleSuccessionRegistry(registry).checkIn();

            assertFalse(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));
        }

        vm.warp(block.timestamp + 181 days);
        assertTrue(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));
    }

    function test_RevertWhen_NotOwnerChecksIn() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 8 days);

        vm.prank(bob);
        vm.expectRevert();
        SimpleSuccessionRegistry(registry).checkIn();
    }

    function test_RevertWhen_AttackerCallsCheckIn() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.prank(attacker);
        vm.expectRevert();
        SimpleSuccessionRegistry(registry).checkIn();
    }

    function test_RevertWhen_CheckInNotConfigured() public {
        vm.prank(alice);
        vm.expectRevert(SimpleSuccessionRegistry.NotConfigured.selector);
        SimpleSuccessionRegistry(registry).checkIn();
    }

    function test_ExecuteSuccession_SixMonths() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        vm.prank(bob);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);

        assertEq(controllerNFT.ownerOf(1), bob);
    }

    function test_ExecuteSuccession_OneYear() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.ONE_YEAR);

        vm.warp(block.timestamp + 366 days);

        vm.prank(bob);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);
        assertEq(controllerNFT.ownerOf(1), bob);
    }

    function test_SuccessionAtExactBoundary_SixMonths() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        uint64 lastCheckIn = SimpleSuccessionRegistry(registry).getPolicy().lastCheckIn;

        vm.warp(lastCheckIn + 180 days - 1);
        assertFalse(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));

        vm.warp(lastCheckIn + 180 days);
        assertTrue(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));
    }

    function test_SuccessionAtExactBoundary_OneYear() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.ONE_YEAR);

        uint64 lastCheckIn = SimpleSuccessionRegistry(registry).getPolicy().lastCheckIn;

        vm.warp(lastCheckIn + 365 days - 1);
        assertFalse(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));

        vm.warp(lastCheckIn + 365 days);
        assertTrue(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));
    }

    function test_RevertWhen_TooEarlyTransfer() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 179 days);

        vm.prank(bob);
        vm.expectRevert(SimpleSuccessionRegistry.ConditionsNotMet.selector);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);

        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(bob);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);
    }

    function test_RevertWhen_NotBeneficiary() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        vm.prank(charlie);
        vm.expectRevert(SimpleSuccessionRegistry.NotBeneficiary.selector);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);
    }

    function test_RevertWhen_AttackerCallsExecuteSuccession() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        vm.prank(attacker);
        vm.expectRevert(SimpleSuccessionRegistry.NotBeneficiary.selector);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);
    }

    function test_RevertWhen_InvalidSubject() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        vm.prank(bob);
        vm.expectRevert(SimpleSuccessionRegistry.InvalidSubject.selector);
        SimpleSuccessionRegistry(registry).executeSuccession(bob);
    }

    function test_RevertWhen_ExecuteTransferNotConfigured() public {
        vm.warp(block.timestamp + 181 days);

        vm.prank(bob);
        vm.expectRevert(SimpleSuccessionRegistry.NotConfigured.selector);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);
    }

    function test_UpdateBeneficiary() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.prank(alice);
        SimpleSuccessionRegistry(registry).updateBeneficiary(charlie);

        SimpleSuccessionRegistry.Policy memory policy =
            SimpleSuccessionRegistry(registry).getPolicy();
        assertEq(policy.beneficiary, charlie);
    }

    function test_UpdateBeneficiary_ResetsTimer() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 170 days);

        uint64 checkInBefore = SimpleSuccessionRegistry(registry).getPolicy().lastCheckIn;

        vm.prank(alice);
        SimpleSuccessionRegistry(registry).updateBeneficiary(charlie);

        uint64 checkInAfter = SimpleSuccessionRegistry(registry).getPolicy().lastCheckIn;

        assertGt(checkInAfter, checkInBefore);
        assertFalse(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));
    }

    function test_BeneficiaryUpdateChangesWhoCanClaim() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.prank(alice);
        SimpleSuccessionRegistry(registry).updateBeneficiary(charlie);

        vm.warp(block.timestamp + 181 days);

        vm.prank(bob);
        vm.expectRevert(SimpleSuccessionRegistry.NotBeneficiary.selector);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);

        vm.prank(charlie);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);
        assertEq(controllerNFT.getCurrentController(alice), charlie);
    }

    function test_RevertWhen_NotOwnerUpdatesBeneficiary() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.prank(bob);
        vm.expectRevert();
        SimpleSuccessionRegistry(registry).updateBeneficiary(charlie);
    }

    function test_RevertWhen_AttackerUpdatesPolicy() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.prank(attacker);
        vm.expectRevert();
        SimpleSuccessionRegistry(registry).updateBeneficiary(attacker);
    }

    function test_RevertWhen_UpdateBeneficiaryNotConfigured() public {
        vm.prank(alice);
        vm.expectRevert(SimpleSuccessionRegistry.NotConfigured.selector);
        SimpleSuccessionRegistry(registry).updateBeneficiary(bob);
    }

    function test_RevertWhen_UpdateBeneficiaryToZero() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.prank(alice);
        vm.expectRevert(SimpleSuccessionRegistry.ZeroAddress.selector);
        SimpleSuccessionRegistry(registry).updateBeneficiary(address(0));
    }

    function test_PartialTransferWhenBeneficiaryAtCapacity() public {
        uint256 maxTokens = controllerNFT.MAX_INHERITED_TOKENS();

        vm.prank(bob);
        factory.createEstate();

        for (uint256 i = 0; i < maxTokens - 1; i++) {
            vm.warp(1);
            address user = makeAddr(string.concat("user", vm.toString(i)));
            vm.deal(user, 10 ether);

            vm.prank(user);
            (, address userRegistry,) = factory.createEstate();

            vm.prank(user);
            SimpleSuccessionRegistry(userRegistry)
                .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

            vm.warp(block.timestamp + 180 days);

            vm.prank(bob);
            SimpleSuccessionRegistry(userRegistry).executeSuccession(user);
        }

        assertEq(controllerNFT.getUserOwnedTokens(bob).length, maxTokens);

        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                SimpleSuccessionRegistry.InsufficientSpace.selector, maxTokens, 1, 0
            )
        );
        SimpleSuccessionRegistry(registry).executeSuccession(alice);
    }

    function test_IsSuccessionOpen_BeforeWaitingPeriod() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        assertFalse(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));
    }

    function test_IsSuccessionOpen_AfterWaitingPeriod() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);
        assertTrue(SimpleSuccessionRegistry(registry).isSuccessionOpen(alice));
    }

    function test_IsSuccessionOpen_WrongSubject() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);
        assertFalse(SimpleSuccessionRegistry(registry).isSuccessionOpen(bob));
    }

    function test_GetStatus() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        (
            bool configured,
            address beneficiary,
            SimpleSuccessionRegistry.WaitPeriod waitPeriod,
            uint64 lastCheckIn,
            uint256 secondsUntilOpen,
            bool isOpen
        ) = SimpleSuccessionRegistry(registry).getStatus();

        assertTrue(configured);
        assertEq(beneficiary, bob);
        assertEq(uint256(waitPeriod), uint256(SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS));
        assertGt(lastCheckIn, 0);
        assertGt(secondsUntilOpen, 0);
        assertFalse(isOpen);
    }

    function test_GetStatus_WhenOpen() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        (,,,, uint256 secondsUntilOpen, bool isOpen) =
            SimpleSuccessionRegistry(registry).getStatus();

        assertEq(secondsUntilOpen, 0);
        assertTrue(isOpen);
    }

    function test_GetPolicy() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.ONE_YEAR);

        SimpleSuccessionRegistry.Policy memory policy =
            SimpleSuccessionRegistry(registry).getPolicy();

        assertEq(policy.beneficiary, bob);
        assertEq(uint256(policy.waitPeriod), uint256(SimpleSuccessionRegistry.WaitPeriod.ONE_YEAR));
        assertTrue(policy.configured);
    }

    function test_GetBeneficiary() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        assertEq(SimpleSuccessionRegistry(registry).getBeneficiary(), bob);
    }

    function test_Gas_ExecuteSuccession() public {
        vm.prank(alice);
        SimpleSuccessionRegistry(registry)
            .setupPolicy(bob, SimpleSuccessionRegistry.WaitPeriod.SIX_MONTHS);

        vm.warp(block.timestamp + 181 days);

        uint256 gasBefore = gasleft();

        vm.prank(bob);
        SimpleSuccessionRegistry(registry).executeSuccession(alice);

        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for executeSuccession", gasUsed);
        assertLt(gasUsed, 200_000);
    }
}
