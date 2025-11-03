// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../interfaces/IPauseControl.sol"; // Added for IPauseControl
import "../modules/security/SecurityLimits.sol"; // Added for ISecurityLimits

/**
 * @title TransferValidation - Validates transfer operations
 * @notice Contains all transfer validation logic
 */
contract TransferValidation {
    address public immutable securityModule;
    address public immutable pauseModule;
    
    event ValidationFailed(
        address indexed from,
        address indexed to,
        uint256 amount,
        string reason
    );
    
    constructor(address _securityModule, address _pauseModule) {
        securityModule = _securityModule;
        pauseModule = _pauseModule;
    }
    
    function validateTransfer(
        address from,
        address to,
        uint256 amount
    ) external view returns (bool) {
        // Basic validations
        require(to != address(0), "TransferValidation: zero address recipient");
        require(amount > 0, "TransferValidation: zero amount");
        
        // Check if transfers are paused
        require(
            !IPauseControl(pauseModule).isPaused(),
            "TransferValidation: transfers paused"
        );
        
        // Check security limits
        require(
            ISecurityLimits(securityModule).checkTransferLimit(from, amount),
            "TransferValidation: security limit exceeded"
        );
        
        return true;
    }
}
