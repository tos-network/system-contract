// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {WTOS} from "../contracts/WTOS.sol";

contract WTOSTest is Test {
    WTOS public wtos;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    uint256 public constant INITIAL_BALANCE = 100 ether;

    function setUp() public {
        wtos = new WTOS();
        vm.deal(alice, INITIAL_BALANCE);
        vm.deal(bob, INITIAL_BALANCE);
    }

    function test_Metadata() public {
        assertEq(wtos.name(), "Wrapped Tos");
        assertEq(wtos.symbol(), "WTOS");
        assertEq(wtos.decimals(), 18);
    }

    function test_Deposit() public {
        uint256 amount = 1 ether;
        vm.prank(alice);
        wtos.deposit{value: amount}();

        assertEq(wtos.balanceOf(alice), amount);
        assertEq(wtos.totalSupply(), amount);
    }

    function test_Withdraw() public {
        uint256 amount = 1 ether;
        
        // First deposit
        vm.prank(alice);
        wtos.deposit{value: amount}();
        
        // Then withdraw
        vm.prank(alice);
        wtos.withdraw(amount);

        assertEq(wtos.balanceOf(alice), 0);
        assertEq(wtos.totalSupply(), 0);
    }

    function test_Transfer() public {
        uint256 amount = 1 ether;
        
        // Alice deposits
        vm.prank(alice);
        wtos.deposit{value: amount}();
        
        // Alice transfers to Bob
        vm.prank(alice);
        wtos.transfer(bob, amount);

        assertEq(wtos.balanceOf(alice), 0);
        assertEq(wtos.balanceOf(bob), amount);
    }

    function test_Approve_And_TransferFrom() public {
        uint256 amount = 1 ether;
        
        // Alice deposits
        vm.prank(alice);
        wtos.deposit{value: amount}();
        
        // Alice approves Bob
        vm.prank(alice);
        wtos.approve(bob, amount);
        
        // Bob transfers from Alice to himself
        vm.prank(bob);
        wtos.transferFrom(alice, bob, amount);

        assertEq(wtos.balanceOf(alice), 0);
        assertEq(wtos.balanceOf(bob), amount);
        assertEq(wtos.allowance(alice, bob), 0);
    }

    function test_InfiniteApproval() public {
        // Alice approves Bob with max amount
        vm.prank(alice);
        wtos.approve(bob, type(uint256).max);
        
        // Alice deposits
        vm.prank(alice);
        wtos.deposit{value: 1 ether}();
        
        // Bob can transfer multiple times without approval decreasing
        vm.startPrank(bob);
        wtos.transferFrom(alice, bob, 0.5 ether);
        wtos.transferFrom(alice, bob, 0.5 ether);
        vm.stopPrank();

        assertEq(wtos.allowance(alice, bob), type(uint256).max);
    }

    function testFail_WithdrawInsufficientBalance() public {
        vm.prank(alice);
        wtos.withdraw(1 ether);
    }

    function testFail_TransferInsufficientBalance() public {
        vm.prank(alice);
        wtos.transfer(bob, 1 ether);
    }

    receive() external payable {}
}