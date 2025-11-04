// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/Context.sol";
import "../events/CoreEvents.sol";
import "../../interfaces/IFeeProcessor.sol"; // Added for IFeeProcessor
import "../integration/SecurityIntegration.sol"; // Added for ISecurityIntegration

/**
 * @title TransferProcessor - Handles all transfer logic and validation
 * @notice Processes transfers including fees, limits, and other checks
 */
contract TransferProcessor is Context {
    address public immutable feeProcessor;
    address public immutable securityModule;
    
    constructor(address _feeProcessor, address _securityModule) {
        feeProcessor = _feeProcessor;
        securityModule = _securityModule;
    }
    
function processTransfer(
        address from,
        address to,
        uint256 amount
    ) external returns (uint256) {
        // Basic input validation
        require(to != address(0), "TransferProcessor: zero address");
        require(amount > 0, "TransferProcessor: zero amount");
        
        // Security checks - delegate to SecurityIntegration
        require(
            ISecurityIntegration(securityModule).validateTransfer(from, to, amount),
            "TransferProcessor: security validation failed"
        );

        // Process fees if applicable
        uint256 processedAmount = amount;
        if (from != address(0) && to != address(0)) {
            processedAmount = _processFees(from, to, amount);
        }
        
        return processedAmount;
    }
    
    function _processFees(
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256) {
        // Call fee processor if it exists
        if (feeProcessor != address(0)) {
            return IFeeProcessor(feeProcessor).processFee(from, to, amount);
        }
        return amount;
    }
}
