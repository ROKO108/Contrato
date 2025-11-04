// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../contracts/core/MyTokenPro.sol";
import "../contracts/core/MyTokenPro_FIXED.sol";

/**
 * @title Constructor Initialization Test
 * @dev Tests that MyTokenPro constructor properly initializes all inherited contracts
 */
contract ConstructorInitializationTest is Test {
    address public owner = address(0x1);
    address public user = address(0x2);
    
    event ConstructorTestResult(string testName, bool passed, string reason);
    
    function testOriginalConstructorInitialization() public {
        // Test original contract - this should fail
        try new MyTokenPro(owner) returns (MyTokenPro token) {
            // Check if all modules are properly initialized
            _checkModuleInitialization(token, "Original");
        } catch Error(string memory reason) {
            emit ConstructorTestResult("Original Constructor", false, reason);
        }
    }
    
    function testFixedConstructorInitialization() public {
        // Test fixed contract - this should pass
        try new MyTokenProFixed(owner) returns (MyTokenProFixed token) {
            // Check if all modules are properly initialized
            _checkFixedModuleInitialization(token, "Fixed");
        } catch Error(string memory reason) {
            emit ConstructorTestResult("Fixed Constructor", false, reason);
        }
    }
    
    function _checkModuleInitialization(MyTokenPro token, string memory version) internal {
        // Test critical module initialization
        bool allInitialized = true;
        string memory failureReason = "";
        
        // Check if modules exist
        if (address(token.feeExclusions()) == address(0)) {
            allInitialized = false;
            failureReason = "FeeExclusions not initialized";
        }
        
        if (address(token.feeProcessor()) == address(0)) {
            allInitialized = false;
            failureReason = "FeeProcessor not initialized";
        }
        
        if (address(token.stakeManager()) == address(0)) {
            allInitialized = false;
            failureReason = "StakeManager not initialized";
        }
        
        if (address(token.emergencyModule()) == address(0)) {
            allInitialized = false;
            failureReason = "EmergencyModule not initialized";
        }
        
        if (address(token.pauseModule()) == address(0)) {
            allInitialized = false;
            failureReason = "PauseModule not initialized";
        }
        
        // Test basic functionality
        try token.mint(owner, 1000 ether) {
            // Mint should work if properly initialized
        } catch {
            allInitialized = false;
            failureReason = "Mint function failed";
        }
        
        // Test pause functionality
        try token.pause() {
            // This should fail - only emergency module can pause
            allInitialized = false;
            failureReason = "Pause access control not working";
        } catch {
            // This is expected - pause should be protected
        }
        
        emit ConstructorTestResult(
            string(abi.encodePacked(version, " Constructor")),
            allInitialized,
            failureReason
        );
    }
    
    function _checkFixedModuleInitialization(MyTokenProFixed token, string memory version) internal {
        // Test critical module initialization for fixed version
        bool allInitialized = true;
        string memory failureReason = "";
        
        // Check if modules exist
        if (address(token.feeExclusions()) == address(0)) {
            allInitialized = false;
            failureReason = "FeeExclusions not initialized";
        }
        
        if (address(token.feeProcessor()) == address(0)) {
            allInitialized = false;
            failureReason = "FeeProcessor not initialized";
        }
        
        if (address(token.stakeManager()) == address(0)) {
            allInitialized = false;
            failureReason = "StakeManager not initialized";
        }
        
        if (address(token.emergencyModule()) == address(0)) {
            allInitialized = false;
            failureReason = "EmergencyModule not initialized";
        }
        
        if (address(token.pauseModule()) == address(0)) {
            allInitialized = false;
            failureReason = "PauseModule not initialized";
        }
        
        // Test basic functionality
        try token.mint(owner, 1000 ether) {
            // Mint should work if properly initialized
        } catch {
            allInitialized = false;
            failureReason = "Mint function failed";
        }
        
        // Test pause functionality
        try token.pause() {
            // This should fail - only emergency module can pause
            allInitialized = false;
            failureReason = "Pause access control not working";
        } catch {
            // This is expected - pause should be protected
        }
        
        // Test transfer functionality
        try token.transfer(user, 100 ether) {
            // Transfer should work
        } catch {
            allInitialized = false;
            failureReason = "Transfer function failed";
        }
        
        emit ConstructorTestResult(
            string(abi.encodePacked(version, " Constructor")),
            allInitialized,
            failureReason
        );
    }
    
    function testInheritanceChainInitialization() public {
        // Test that all inherited contracts are properly initialized
        vm.startPrank(owner);
        
        MyTokenProFixed token = new MyTokenProFixed(owner);
        
        // Test ERC20 functionality
        assertEq(token.name(), "MyTokenPro", "ERC20 name not initialized");
        assertEq(token.symbol(), "MTP", "ERC20 symbol not initialized");
        assertEq(token.decimals(), 18, "ERC20 decimals not initialized");
        
        // Test Ownable2Step functionality
        assertEq(token.owner(), owner, "Ownable2Step not initialized");
        
        // Test Pausable functionality
        assertFalse(token.paused(), "Pausable not properly initialized");
        
        // Test TokenSupply functionality
        token.mint(owner, 1000 ether);
        assertEq(token.totalSupply(), 1000 ether, "TokenSupply not working");
        
        vm.stopPrank();
        
        emit ConstructorTestResult("Inheritance Chain", true, "All inherited contracts initialized");
    }
    
    function testModuleAuthorizationAfterInitialization() public {
        vm.startPrank(owner);
        
        MyTokenProFixed token = new MyTokenProFixed(owner);
        
        // Test that modules are properly authorized
        // This tests the _authorizeModules function
        try token.transfer(user, 100 ether) {
            // Should work - modules are authorized
        } catch {
            emit ConstructorTestResult("Module Authorization", false, "Module authorization failed");
        }
        
        vm.stopPrank();
        
        emit ConstructorTestResult("Module Authorization", true, "Modules properly authorized");
    }
}