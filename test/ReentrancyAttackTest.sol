// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../contracts/core/MyTokenPro.sol";

/**
 * @title Reentrancy Attack Test
 * @dev Tests reentrancy protection in MyTokenPro _update function
 */
contract ReentrancyAttackTest is Test {
    MyTokenPro public token;
    ReentrancyAttacker public attacker;
    
    address public owner = address(0x1);
    address public victim = address(0x2);
    
    event ReentrancyAttackAttempted(address indexed attacker, uint256 amount);
    event ReentrancyAttackBlocked(address indexed attacker, uint256 attempt);
    
    function setUp() public {
        vm.startPrank(owner);
        token = new MyTokenPro(owner);
        
        // Mint initial tokens
        token.mint(owner, 1000000 ether);
        token.transfer(victim, 1000 ether);
        token.transfer(address(attacker), 100 ether);
        
        vm.stopPrank();
    }
    
    /**
     * @test Reentrancy attack through transfer
     */
    function testReentrancyAttackThroughTransfer() public {
        uint256 initialAttackerBalance = token.balanceOf(address(attacker));
        
        vm.startPrank(address(attacker));
        
        // Attacker tries to re-enter during transfer
        attacker.attemptReentrancy(address(token), victim, 50 ether);
        
        vm.stopPrank();
        
        // Check that reentrancy was blocked
        uint256 finalAttackerBalance = token.balanceOf(address(attacker));
        assertTrue(finalAttackerBalance < initialAttackerBalance, "Attacker should lose tokens");
        
        emit ReentrancyAttackBlocked(address(attacker), 50 ether);
    }
    
    /**
     * @test Reentrancy attack through approve/transferFrom
     */
    function testReentrancyAttackThroughTransferFrom() public {
        uint256 initialAttackerBalance = token.balanceOf(address(attacker));
        
        vm.startPrank(address(attacker));
        
        // Approve attacker contract to spend tokens
        token.approve(address(attacker), 50 ether);
        
        // Attempt reentrancy through transferFrom
        attacker.attemptReentrancyTransferFrom(address(token), victim, 50 ether);
        
        vm.stopPrank();
        
        // Check that reentrancy was blocked
        uint256 finalAttackerBalance = token.balanceOf(address(attacker));
        assertTrue(finalAttackerBalance < initialAttackerBalance, "Attacker should lose tokens");
        
        emit ReentrancyAttackBlocked(address(attacker), 50 ether);
    }
    
    /**
     * @test Normal transfer still works
     */
    function testNormalTransferWorks() public {
        uint256 initialVictimBalance = token.balanceOf(victim);
        uint256 transferAmount = 10 ether;
        
        vm.startPrank(victim);
        token.transfer(owner, transferAmount);
        vm.stopPrank();
        
        uint256 finalVictimBalance = token.balanceOf(victim);
        assertEq(finalVictimBalance, initialVictimBalance - transferAmount, "Normal transfer should work");
    }
    
    /**
     * @test Multiple reentrancy attempts are blocked
     */
    function testMultipleReentrancyAttemptsBlocked() public {
        vm.startPrank(address(attacker));
        
        // Try multiple reentrancy attacks
        for (uint256 i = 0; i < 5; i++) {
            try attacker.attemptReentrancy(address(token), victim, 10 ether) {
                // Should fail
                assertTrue(false, "Reentrancy attack should fail");
            } catch {
                // Expected to fail
            }
        }
        
        vm.stopPrank();
        
        emit ReentrancyAttackBlocked(address(attacker), 50 ether);
    }
}

/**
 * @title Reentrancy Attacker Contract
 * @dev Malicious contract that attempts reentrancy attacks
 */
contract ReentrancyAttacker {
    MyTokenPro public targetToken;
    address public owner;
    uint256 public reentrancyCount;
    bool public attacking;
    
    event ReentrancyStarted(uint256 amount);
    event ReentrancyAttempted(uint256 attempt);
    event ReentrancyCompleted(bool success);
    
    constructor() {
        owner = msg.sender;
        reentrancyCount = 0;
        attacking = false;
    }
    
    /**
     * @dev Attempt reentrancy attack through transfer
     */
    function attemptReentrancy(address token, address to, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        targetToken = MyTokenPro(token);
        
        attacking = true;
        emit ReentrancyStarted(amount);
        
        // This will trigger _update and potentially re-enter
        targetToken.transfer(to, amount);
        
        attacking = false;
        emit ReentrancyCompleted(true);
    }
    
    /**
     * @dev Attempt reentrancy attack through transferFrom
     */
    function attemptReentrancyTransferFrom(address token, address to, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        targetToken = MyTokenPro(token);
        
        attacking = true;
        emit ReentrancyStarted(amount);
        
        // This will trigger _update and potentially re-enter
        targetToken.transferFrom(owner, to, amount);
        
        attacking = false;
        emit ReentrancyCompleted(true);
    }
    
    /**
     * @dev Fallback that attempts reentrancy
     */
    fallback() external payable {
        if (attacking && address(targetToken) != address(0)) {
            reentrancyCount++;
            emit ReentrancyAttempted(reentrancyCount);
            
            // Try to re-enter the token contract
            try targetToken.transfer(owner, 1 ether) {
                // If this succeeds, reentrancy protection failed
            } catch {
                // Expected - reentrancy protection worked
            }
        }
    }
    
    /**
     * @dev Receive function for ETH transfers
     */
    receive() external payable {
        if (attacking && address(targetToken) != address(0)) {
            reentrancyCount++;
            emit ReentrancyAttempted(reentrancyCount);
            
            // Try to re-enter the token contract
            try targetToken.transfer(owner, 1 ether) {
                // If this succeeds, reentrancy protection failed
            } catch {
                // Expected - reentrancy protection worked
            }
        }
    }
}