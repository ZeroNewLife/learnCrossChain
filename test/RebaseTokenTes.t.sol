//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test,console} from "forge-std/Test.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner=makeAddr("owner");
    address public user=makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken =new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grandMinterBurnRole(address(vault));
        (bool succes,)=payable(address(vault)).call{value:1e18}("");
        vm.stopPrank();
    }


    function testDepositLinear(uint256 amount) public {
        vm.assume(amount>1e5);
        amount=bound(amount,1e5,type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value:amount}();

        uint256 startBalance=rebaseToken.balanceOf(user);
        console.log("Start balance:",startBalance);
        assertEq(startBalance,amount);

        vm.warp(block.timestamp +1 hours);
        uint256 midleBalance=rebaseToken.balanceOf(user);
        console.log("Midle balance after 1 hour:",midleBalance);
        assertGt(midleBalance,startBalance);


        vm.warp(block.timestamp +1 hours);
        uint256 endBalance=rebaseToken.balanceOf(user);
        console.log("End balance after 2 hours:",endBalance);
        assertGt(endBalance,midleBalance);


        assertApproxEqAbs(endBalance - midleBalance, midleBalance - startBalance ,1);
        vm.stopPrank();
    }


    function testRedeemStraighAway(uint256 amount) public {

        amount=bound(amount,1e5,type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value:amount}();

        assertEq(rebaseToken.balanceOf(user),amount);
        vault.redeem(type(uint256).max);

        assertEq(rebaseToken.balanceOf(user),0);

        assertEq(address(user).balance,amount);
            
        vm.stopPrank();

    }

}
