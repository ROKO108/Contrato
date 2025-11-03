// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title SecurityEvents - Security-specific events
 * @notice Contains all security-related events used across the system
 */
contract SecurityEvents {
    // Emergency events
    event EmergencyTriggered(address indexed trigger, string reason);
    event EmergencyResolved(address indexed resolver);
    
    // Security limit events
    event SecurityLimitUpdated(string limitType, uint256 newLimit);
    event SecurityLimitBreached(
        address indexed user,
        string limitType,
        uint256 attempted,
        uint256 limit
    );
    
    // Pause events
    event SystemPaused(address indexed pauser, string reason);
    event SystemUnpaused(address indexed unpauser);
    
    // Anti-abuse events
    event FlashLoanAttempted(address indexed user, uint256 amount);
    event SuspiciousActivityDetected(
        address indexed account,
        string activityType,
        uint256 timestamp
    );
}