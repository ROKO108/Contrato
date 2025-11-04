// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../contracts/core/MyTokenPro.sol";
import "../contracts/modules/staking/RewardManager.sol";
import "../contracts/modules/staking/StakeManager.sol";
import "../contracts/libraries/SafetyChecks.sol";
import "forge-std/Test.sol";

/**
 * @title MintFunctionSecurityTest
 * @dev Tests for mint function access control vulnerability fix
 */
contract MintFunctionSecurityTest is Test {
    MyTokenPro public token;
    RewardManager public rewardManager;
    StakeManager public stakeManager;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    address public attacker = address(0x3);
    
    uint256 public constant MAX_SUPPLY = 100_000_000 * 1e18;
    uint256 public constant MAX_MINT_PER_CALL = 1_000_000 * 1e18;
    
    event Mint(address indexed to, uint256 amount, uint256 totalMinted);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy fixed version
        token = new MyTokenPro();
        
        // Get module addresses
        stakeManager = token.stakeManager();
        rewardManager = token.rewardManager();
        
        // Fund reward manager with tokens for testing
        vm.deal(address(this), 1000 ether);
        token.transfer(address(rewardManager), 10_000 * 1e18);
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test that mint function has been removed (security fix)
     */
    function testMintFunctionRemoved() public {
        // Try to call mint function - should fail
        vm.startPrank(address(rewardManager));
        
        // This should fail because mint function no longer exists
        vm.expectRevert(); // Function doesn't exist
        (bool success,) = address(token).call(
            abi.encodeWithSignature("mint(address,uint256)", user, 1000 * 1e18)
        );
        assertFalse(success, "Mint function should not exist");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test that reward system works without minting
     */
    function testRewardSystemWithoutMint() public {
        // Stake some tokens
        vm.startPrank(user);
        token.approve(address(stakeManager), 1000 * 1e18);
        stakeManager.stake(1000 * 1e18);
        vm.stopPrank();
        
        // Fast forward time
        vm.roll(block.number + 1000);
        
        // Claim rewards - should work with existing supply
        vm.startPrank(user);
        uint256 balanceBefore = token.balanceOf(user);
        
        // This should work using existing token supply
        rewardManager.claimReward();
        
        uint256 balanceAfter = token.balanceOf(user);
        assertGt(balanceAfter, balanceBefore, "Should receive rewards from existing supply");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test that no new tokens can be created
     */
    function testNoNewTokenCreation() public {
        uint256 totalSupplyBefore = token.totalSupply();
        
        // Try various attack vectors to create new tokens
        vm.startPrank(attacker);
        
        // 1. Direct mint call
        (bool success1,) = address(token).call(
            abi.encodeWithSignature("mint(address,uint256)", attacker, 1000 * 1e18)
        );
        assertFalse(success1, "Direct mint should fail");
        
        // 2. Attempt to call mint through delegatecall
        (bool success2,) = address(token).delegatecall(
            abi.encodeWithSignature("mint(address,uint256)", attacker, 1000 * 1e18)
        );
        assertFalse(success2, "Delegatecall mint should fail");
        
        // 3. Try to call any function that might mint
        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = token.mint.selector;
        selectors[1] = token.mintTo.selector;
        selectors[2] = token.createTokens.selector;
        selectors[3] = token.issue.selector;
        selectors[4] = token.generate.selector;
        selectors[5] = token.print.selector;
        selectors[6] = token.fabricate.selector;
        selectors[7] = token.produce.selector;
        selectors[8] = token.manufacture.selector;
        selectors[9] = token.supply.selector;
        
        for (uint256 i = 0; i < selectors.length; i++) {
            (bool success3,) = address(token).call(abi.encodeWithSelector(selectors[i], attacker, 1000 * 1e18));
            assertFalse(success3, "Mint-like function should fail");
        }
        
        vm.stopPrank();
        
        uint256 totalSupplyAfter = token.totalSupply();
        assertEq(totalSupplyBefore, totalSupplyAfter, "Total supply should not change");
    }
    
    /**
     * @dev Test reward manager uses existing supply correctly
     */
    function testRewardManagerUsesExistingSupply() public {
        uint256 rewardManagerBalanceBefore = token.balanceOf(address(rewardManager));
        
        // Stake and claim rewards
        vm.startPrank(user);
        token.approve(address(stakeManager), 1000 * 1e18);
        stakeManager.stake(1000 * 1e18);
        
        vm.roll(block.number + 1000);
        
        uint256 userBalanceBefore = token.balanceOf(user);
        rewardManager.claimReward();
        uint256 userBalanceAfter = token.balanceOf(user);
        vm.stopPrank();
        
        uint256 rewardManagerBalanceAfter = token.balanceOf(address(rewardManager));
        
        // Verify rewards came from existing supply
        assertGt(userBalanceAfter, userBalanceBefore, "User should receive rewards");
        assertLt(rewardManagerBalanceAfter, rewardManagerBalanceBefore, "Reward manager balance should decrease");
        
        // Total supply should remain constant
        uint256 totalSupply = token.totalSupply();
        assertEq(totalSupply, MAX_SUPPLY, "Total supply should remain at max");
    }
    
    /**
     * @dev Test economic model with fixed supply
     */
    function testFixedSupplyEconomicModel() public {
        // Verify initial supply
        assertEq(token.totalSupply(), MAX_SUPPLY, "Initial supply should be max");
        
        // Simulate multiple users staking and claiming rewards
        address[] memory users = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            users[i] = address(uint160(0x100 + i));
            
            vm.startPrank(users[i]);
            token.transferFrom(owner, users[i], 1000 * 1e18);
            token.approve(address(stakeManager), 1000 * 1e18);
            stakeManager.stake(1000 * 1e18);
            vm.stopPrank();
        }
        
        // Fast forward and let rewards accumulate
        vm.roll(block.number + 5000);
        
        // All users claim rewards
        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(users[i]);
            rewardManager.claimReward();
            vm.stopPrank();
        }
        
        // Total supply should still be constant
        assertEq(token.totalSupply(), MAX_SUPPLY, "Supply should remain constant after rewards");
        
        // Reward manager should have less tokens (distributed to users)
        uint256 rewardManagerBalance = token.balanceOf(address(rewardManager));
        assertLt(rewardManagerBalance, 10_000 * 1e18, "Reward manager should have distributed tokens");
    }
    
    /**
     * @dev Test attack scenario: attempting to drain reward manager
     */
    function testRewardManagerDrainAttack() public {
        uint256 initialRewardBalance = token.balanceOf(address(rewardManager));
        
        // Attacker tries to claim all rewards
        vm.startPrank(attacker);
        
        // Should fail - attacker has no staked tokens
        vm.expectRevert();
        rewardManager.claimReward();
        
        vm.stopPrank();
        
        // Reward manager balance should be unchanged
        assertEq(
            token.balanceOf(address(rewardManager)), 
            initialRewardBalance, 
            "Attack should not affect reward manager"
        );
    }
    
    /**
     * @dev Test gas efficiency without mint function
     */
    function testGasEfficiencyWithoutMint() public {
        vm.startPrank(user);
        token.approve(address(stakeManager), 1000 * 1e18);
        
        uint256 gasBefore = gasleft();
        stakeManager.stake(1000 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Staking should be gas efficient without mint function overhead
        assertLt(gasUsed, 200000, "Staking should be gas efficient");
        
        vm.stopPrank();
    }
}