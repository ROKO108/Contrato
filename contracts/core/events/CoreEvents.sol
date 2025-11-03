// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title CoreEvents - Central event definitions
 * @notice Contains all core events used across the token system
 */
contract CoreEvents {
    // Core token events
    event Mint(address indexed to, uint256 amount, uint256 totalMinted);
    event Burn(address indexed from, uint256 amount);
    
    // Security events
    event SecurityLimitHit(string limitType, address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount);
    event AntiFlashLoanTriggered(address indexed user, uint256 blocksStaked);
    
    // Module integration events
    event ModuleUpdated(string indexed moduleType, address indexed module);
    event ConfigurationChanged(string indexed parameter, uint256 newValue);
}