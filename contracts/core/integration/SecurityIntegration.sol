// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../access/ModuleAccess.sol";
import "../modules/security/SecurityLimits.sol"; // Added for ISecurityLimits

/**
 * @title SecurityIntegration - Manages security-related integrations
 * @notice Coordinates security modules and their interactions
 */
contract SecurityIntegration is ModuleAccess {
    address public immutable emergencyModule;
    address public immutable pauseModule;
    address public immutable securityLimits;
    
    bytes4 public constant EMERGENCY_ROLE = bytes4(keccak256("EMERGENCY_ROLE"));
    bytes4 public constant SECURITY_LIMIT_ROLE = bytes4(keccak256("SECURITY_LIMIT_ROLE"));
    
    event SecurityActionTriggered(string action, address indexed module, uint256 timestamp);
    
    constructor(
        address _emergencyModule,
        address _pauseModule,
        address _securityLimits
    ) {
        emergencyModule = _emergencyModule;
        pauseModule = _pauseModule;
        securityLimits = _securityLimits;
        
        authorizeModule(_emergencyModule, EMERGENCY_ROLE);
        authorizeModule(_securityLimits, SECURITY_LIMIT_ROLE);
    }
    
    function validateTransfer(address from, address to, uint256 amount) 
        external 
        view 
        onlyAuthorizedModule(SECURITY_LIMIT_ROLE) // Only authorized security limits module can call this
        returns (bool) 
    {
        // Delegate security validations to the securityLimits module
        return ISecurityLimits(securityLimits).checkTransferLimit(from, amount);
    }
    
    function emergencyAction(string calldata action) 
        external 
        onlyAuthorizedModule(EMERGENCY_ROLE) 
    {
        emit SecurityActionTriggered(action, msg.sender, block.timestamp);
    }
}
