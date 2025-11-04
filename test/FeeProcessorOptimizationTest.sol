// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../contracts/modules/fees/FeeProcessor.sol";
import "../contracts/modules/fees/FeeExclusions.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FeeProcessorOptimizationTest is Test {
    FeeProcessor public feeProcessor;
    FeeExclusions public feeExclusions;
    MockERC20 public mockToken;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    uint256 public constant INITIAL_FEE = 25; // 2.5%
    uint256 public constant MIN_FEE = 5;     // 0.5%
    uint256 public constant MAX_FEE = 100;   // 10%
    
    function setUp() public {
        vm.startPrank(owner);
        
        mockToken = new MockERC20("Test Token", "TEST");
        feeExclusions = new FeeExclusions(owner);
        feeProcessor = new FeeProcessor(
            owner,
            address(feeExclusions),
            INITIAL_FEE,
            MIN_FEE,
            MAX_FEE
        );
        
        vm.stopPrank();
    }
    
    function testFeeCalculationOptimization() public {
        uint256 amount = 1000 ether;
        uint256 expectedFee = (amount * INITIAL_FEE) / 1000; // 2.5%
        uint256 expectedAmountAfterFee = amount - expectedFee;
        
        uint256 amountAfterFee = feeProcessor.processFee(user1, user2, amount);
        
        assertEq(amountAfterFee, expectedAmountAfterFee, "Fee calculation incorrect");
    }
    
    function testExcludedAddressesNoFee() public {
        vm.startPrank(owner);
        feeExclusions.setExcludedFromFees(user1, true);
        vm.stopPrank();
        
        uint256 amount = 1000 ether;
        uint256 amountAfterFee = feeProcessor.processFee(user1, user2, amount);
        
        assertEq(amountAfterFee, amount, "Excluded address should not pay fee");
    }
    
    function testZeroAmountHandling() public {
        uint256 amount = 0;
        
        vm.expectRevert("Fee: amount must be > 0");
        feeProcessor.processFee(user1, user2, amount);
    }
    
    function testFeeBoundsChecking() public {
        uint256 amount = 1000 ether;
        
        // Test with maximum fee
        vm.startPrank(owner);
        feeProcessor.setFeeRange(MAX_FEE, MAX_FEE, bytes32(0), bytes32(0));
        vm.stopPrank();
        
        uint256 amountAfterFee = feeProcessor.processFee(user1, user2, amount);
        uint256 expectedAmountAfterFee = amount - (amount * MAX_FEE) / 1000;
        
        assertEq(amountAfterFee, expectedAmountAfterFee, "Max fee calculation incorrect");
    }
    
    function testGasOptimization() public {
        uint256 amount = 1000 ether;
        
        uint256 gasBefore = gasleft();
        feeProcessor.processFee(user1, user2, amount);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Gas usage should be reasonable (less than 50,000 gas)
        assertTrue(gasUsed < 50000, "Gas usage too high");
    }
    
    function testFeeUpdateCooldown() public {
        uint256 stakingPool = 1000 ether;
        uint256 totalSupply = 10000 ether;
        
        // First update should succeed
        feeProcessor.updateFee(stakingPool, totalSupply);
        
        // Immediate second update should be blocked by cooldown
        uint256 feeBefore = feeProcessor.feePercent();
        feeProcessor.updateFee(stakingPool, totalSupply);
        uint256 feeAfter = feeProcessor.feePercent();
        
        assertEq(feeBefore, feeAfter, "Fee should not update due to cooldown");
    }
}

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 ether);
    }
}