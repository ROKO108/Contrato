// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../contracts/modules/security/EmergencyModule.sol";
import "../contracts/modules/fees/FeeProcessor.sol";
import "../contracts/modules/fees/FeeExclusions.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EmergencyModuleSecurityTest is Test {
    EmergencyModule public emergencyModule;
    MockERC20 public mockToken;
    
    address public owner = address(0x1);
    address public attacker = address(0x2);
    address public recipient = address(0x3);
    
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount);
    
    function setUp() public {
        vm.startPrank(owner);
        mockToken = new MockERC20("Test Token", "TEST");
        emergencyModule = new EmergencyModule(owner);
        vm.stopPrank();
    }
    
    function testEmergencyWithdrawOnlyOwner() public {
        vm.startPrank(attacker);
        
        vm.expectRevert("Ownable: caller is not the owner");
        emergencyModule.emergencyWithdraw(
            address(mockToken),
            recipient,
            100 ether,
            0,
            0
        );
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdrawCooldown() public {
        vm.startPrank(owner);
        
        // First withdrawal should succeed
        emergencyModule.emergencyWithdraw(
            address(mockToken),
            recipient,
            100 ether,
            0,
            0
        );
        
        // Second withdrawal within cooldown should fail
        vm.expectRevert("Emergency cooldown not met");
        emergencyModule.emergencyWithdraw(
            address(mockToken),
            recipient,
            100 ether,
            0,
            0
        );
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdrawMaxLimit() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Amount exceeds emergency limit");
        emergencyModule.emergencyWithdraw(
            address(mockToken),
            recipient,
            2000 ether, // Exceeds MAX_EMERGENCY_WITHDRAW
            0,
            0
        );
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdrawZeroAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Zero address");
        emergencyModule.emergencyWithdraw(
            address(0),
            recipient,
            100 ether,
            0,
            0
        );
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdrawToSelf() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Cannot withdraw to self");
        emergencyModule.emergencyWithdraw(
            address(mockToken),
            address(emergencyModule),
            100 ether,
            0,
            0
        );
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdrawZeroAmount() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Amount must be greater than 0");
        emergencyModule.emergencyWithdraw(
            address(mockToken),
            recipient,
            0,
            0,
            0
        );
        
        vm.stopPrank();
    }
}

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 ether);
    }
}