// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../access/ModuleAccess.sol";
import "../../interfaces/IFeeProcessor.sol"; // Added for IFeeProcessor
import "../../modules/fees/FeeExclusions.sol"; // Added for IFeeExclusions

/**
 * @title FeeIntegration - Manages fee-related integrations
 * @notice Coordinates fee processing and exclusions
 */
contract FeeIntegration is ModuleAccess {
    address public immutable feeProcessor;
    address public immutable feeExclusions;
    
    bytes4 public constant FEE_PROCESSOR_ROLE = bytes4(keccak256("FEE_PROCESSOR_ROLE"));
    bytes4 public constant FEE_EXCLUSION_ROLE = bytes4(keccak256("FEE_EXCLUSION_ROLE"));
    
    event FeeProcessed(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 fee
    );
    
    constructor(
        address _feeProcessor,
        address _feeExclusions
    ) {
        feeProcessor = _feeProcessor;
        feeExclusions = _feeExclusions;
        
        authorizeModule(_feeProcessor, FEE_PROCESSOR_ROLE);
        authorizeModule(_feeExclusions, FEE_EXCLUSION_ROLE);
    }
    
    function processFee(
        address from,
        address to,
        uint256 amount
    ) external onlyAuthorizedModule(FEE_PROCESSOR_ROLE) returns (uint256) {
        // Implement fee processing logic
        uint256 fee = 0; // Calculate fee based on amount
        emit FeeProcessed(from, to, amount, fee);
        return amount - fee;
    }
    
    function isExcluded(address account) external view returns (bool) {
        return IFeeExclusions(feeExclusions).isExcluded(account);
    }
}
