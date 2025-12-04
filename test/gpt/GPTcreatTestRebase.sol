// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/RebaseToken.sol";
import "../../src/Vault.sol";

contract RebaseTokenTest is Test {
    RebaseToken token;
    Vault vault;

    address alice = address(0xA1);
    address bob = address(0xB2);

    uint256 constant INITIAL_RATE = 5e10;

    function setUp() public {
        token = new RebaseToken();
        vault = new Vault(IRebaseToken(address(token)));

        // grant vault role
        token.grandMinterBurnRole(address(vault));

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    // -----------------------------
    // BASIC STATE
    // -----------------------------
    function testInitialSetup() public {
        assertEq(token.name(), "Rebase Token");
        assertEq(token.symbol(), "RBT");
        assertEq(token.getUserInterestRate(alice), 0);
    }

    // -----------------------------
    // DEPOSIT
    // -----------------------------
    function testDepositMintsTokens() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        assertEq(token.principalBalanceOf(alice), 1 ether);
        assertEq(token.balanceOf(alice), 1 ether);
        assertEq(token.getUserInterestRate(alice), INITIAL_RATE);
    }

    // -----------------------------
    // INTEREST ACCRUAL (VIEW)
    // -----------------------------
    function testInterestAccumulatesOverTime() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        uint256 beforeInterest = token.balanceOf(alice);

        vm.warp(block.timestamp + 10);

        uint256 afterInterest = token.balanceOf(alice);

        assertGt(afterInterest, beforeInterest);
    }

    // -----------------------------
    // TRANSFER: RECEIVER WITH ZERO BALANCE → GET SAME RATE
    // -----------------------------
    function testTransferSetsRecipientRateCorrectly() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.warp(block.timestamp + 5);

        vm.prank(alice);
        token.transfer(bob, 0.5 ether);

        // Bob gets sender rate because he had zero balance
        assertEq(token.getUserInterestRate(bob), token.getUserInterestRate(alice));

        // Bob gets EXACTLY the transferred amount (no interest)
        assertEq(token.balanceOf(bob), 0.5 ether);

        // Alice still > 0.5 due to interest
        assertGt(token.balanceOf(alice), 0.5 ether);
    }

    // -----------------------------
    // TRANSFER MAX UINT
    // -----------------------------
    function testTransferMaxUintTransfersAllPrincipal() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.warp(block.timestamp + 10);

        // FIRST: simulate internal interest mint
        uint256 newPrincipal = token.balanceOf(alice);

        vm.prank(alice);
        token.transfer(bob, type(uint256).max);

        assertEq(token.principalBalanceOf(alice), 0);
        assertEq(token.principalBalanceOf(bob), newPrincipal);
    }

    // -----------------------------
    // MINT & ROLE CHECK
    // -----------------------------
    function testMintRevertsForNonRole() public {
        vm.expectRevert();
        token.mint(bob, 1 ether);
    }

    // -----------------------------
    // INTEREST RATE LOGIC
    // -----------------------------
    function testInterestRateDecreaseReverts() public {
        // decrease SHOULD revert
        vm.expectRevert();
        token.setInterestRate(INITIAL_RATE - 1);
    }

    function testIncreaseInterestRateAllowed() public {
        uint256 newRate = INITIAL_RATE + 1;
        token.setInterestRate(newRate);
        // no revert expected
    }

    // -----------------------------
    // BURN
    // -----------------------------
    function testBurnReducesPrincipal() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.warp(block.timestamp + 5);

        uint256 before = token.balanceOf(alice);

        vm.prank(address(vault));
        token.burn(alice, 0.3 ether);

        uint256 afterBal = token.balanceOf(alice);

        assertLt(afterBal, before);
    }

    // -----------------------------
    // REDEEM (NORMAL)
    // -----------------------------
    function testRedeemReturnsETH() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        vm.warp(block.timestamp + 3);

        uint256 before = alice.balance;

        vm.prank(alice);
        vault.redeem(1 ether);

        uint256 afterBal = alice.balance;

        assertGt(afterBal, before);
    }

    // -----------------------------
    // REDEEM(MAX) WITHOUT INTEREST
    // -----------------------------
    function testRedeemMaxWorksWithoutInterest() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        // NO TIME WARP → no interest

        vm.prank(alice);
        vault.redeem(type(uint256).max);

        assertEq(token.balanceOf(alice), 0);
        assertEq(alice.balance, 100 ether); // fully refunded
    }

    // -----------------------------
    // REDEEM(MAX) WITH INTEREST SHOULD REVERT
    // -----------------------------
    function testRedeemMaxRevertsIfInterestAccrued() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        vm.expectRevert(Vault.Vault__ReddemFailed.selector);
        vault.redeem(type(uint256).max);
    }
}
