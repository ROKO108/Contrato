// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../contracts/core/MyTokenPro.sol";
import "../contracts/modules/fees/FeeProcessor.sol";
import "../contracts/modules/fees/FeeExclusions.sol";
import "../contracts/modules/security/EmergencyModule.sol";
import "../contracts/modules/security/PauseModule.sol";
import "../contracts/modules/security/SecurityLimits.sol";
import "../contracts/modules/staking/StakeManager.sol";
import "../contracts/modules/staking/RewardManager.sol";
import "../contracts/modules/governance/TimelockManager.sol";
import "../contracts/modules/governance/SnapshotManager.sol";
import "../contracts/core/integration/SecurityIntegration.sol";
import "../contracts/core/integration/StakingIntegration.sol";
import "../contracts/core/integration/FeeIntegration.sol";
import "../contracts/core/integration/GovernanceIntegration.sol";
import "../contracts/core/transfer/TransferProcessor.sol";
import "../contracts/core/transfer/TransferValidation.sol";

contract IntegrationTest is Test {
    MyTokenPro public token;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    function setUp() public {
        vm.startPrank(owner);
        token = new MyTokenPro(owner);
        
        // Mint initial tokens for testing
        token.mint(owner, 1000000 ether);
        token.transfer(user1, 1000 ether);
        
        vm.stopPrank();
    }
    
    function testModuleAuthorizationConsistency() public {
        // Test that all modules are properly authorized
        assertTrue(address(token.securityIntegration()) != address(0), "Security integration not set");
        assertTrue(address(token.stakingIntegration()) != address(0), "Staking integration not set");
        assertTrue(address(token.feeIntegration()) != address(0), "Fee integration not set");
        assertTrue(address(token.governanceIntegration()) != address(0), "Governance integration not set");
    }
    
    function testTransferWithAllModules() public {
        uint256 amount = 100 ether;
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 user2BalanceBefore = token.balanceOf(user2);
        
        vm.startPrank(user1);
        token.transfer(user2, amount);
        vm.stopPrank();
        
        uint256 user1BalanceAfter = token.balanceOf(user1);
        uint256 user2BalanceAfter = token.balanceOf(user2);
        
        assertEq(user1BalanceAfter, user1BalanceBefore - amount, "User1 balance incorrect");
        assertTrue(user2BalanceAfter > user2BalanceBefore, "User2 should receive tokens after fees");
    }
    
    function testStakingIntegration() public {
        uint256 stakeAmount = 50 ether;
        
        vm.startPrank(user1);
        token.stake(stakeAmount);
        
        uint256 stakedBalance = token.stakedBalance(user1);
        assertEq(stakedBalance, stakeAmount, "Staked balance incorrect");
        
        token.unstake(stakeAmount);
        uint256 unstakedBalance = token.stakedBalance(user1);
        assertEq(unstakedBalance, 0, "Unstake failed");
        
        vm.stopPrank();
    }
    
    function testEmergencyModuleIntegration() public {
        uint256 emergencyAmount = 10 ether;
        
        vm.startPrank(owner);
        
        // Test emergency pause
        token.pause();
        assertTrue(token.paused(), "Token should be paused");
        
        token.unpause();
        assertFalse(token.paused(), "Token should be unpaused");
        
        vm.stopPrank();
    }
    
    function testFeeIntegration() public {
        uint256 amount = 100 ether;
        
        vm.startPrank(user1);
        uint256 balanceBefore = token.balanceOf(user2);
        
        token.transfer(user2, amount);
        
        uint256 balanceAfter = token.balanceOf(user2);
        
        // User2 should receive slightly less than amount due to fees
        assertTrue(balanceAfter > balanceBefore, "Transfer failed");
        assertTrue(balanceAfter < balanceBefore + amount, "No fees applied");
        
        vm.stopPrank();
    }
    
    function testGovernanceIntegration() public {
        vm.startPrank(owner);
        
        uint256 snapshotId = token.snapshot();
        assertTrue(snapshotId > 0, "Snapshot creation failed");
        
        vm.stopPrank();
    }
    
    function testModuleInteractionConsistency() public {
        // Test that modules work together without conflicts
        uint256 stakeAmount = 10 ether;
        uint256 transferAmount = 20 ether;
        
        vm.startPrank(user1);
        
        // Stake some tokens
        token.stake(stakeAmount);
        
        // Transfer remaining tokens
        token.transfer(user2, transferAmount);
        
        // Verify all operations completed successfully
        assertEq(token.stakedBalance(user1), stakeAmount, "Staking failed");
        assertTrue(token.balanceOf(user2) >= transferAmount * 0.9, "Transfer failed");
        
        vm.stopPrank();
    }
}