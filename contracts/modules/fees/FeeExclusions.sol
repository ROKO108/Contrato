// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../interfaces/IFeeProcessor.sol";
import "../../libraries/MathUtils.sol";
import "../../libraries/SafetyChecks.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FeeExclusions
 * @dev Gestión de exclusiones de fees
 */
contract FeeExclusions is Ownable {
    uint256 private constant MAX_EXCLUDED_ACCOUNTS = 100;
    
    uint256 private _excludedCount;
    mapping(address => bool) private _excludedFromFees;

    event FeeExclusionSet(address indexed account, bool excluded);

    error MaxExcludedReached();
    error InvalidExclusionTarget();

    constructor(address initialOwner) Ownable(initialOwner) {
        require(initialOwner != address(0), "Owner cannot be zero address");
    }

    function setExcludedFromFees(address account, bool excluded) external onlyOwner {
        if (account == address(0) || account == address(this)) {
            revert InvalidExclusionTarget();
        }

        if (excluded && !_excludedFromFees[account]) {
            if (_excludedCount >= MAX_EXCLUDED_ACCOUNTS) {
                revert MaxExcludedReached();
            }
            _excludedCount++;
        } else if (!excluded && _excludedFromFees[account]) {
            _excludedCount--;
        }

        _excludedFromFees[account] = excluded;
        emit FeeExclusionSet(account, excluded);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _excludedFromFees[account];
    }

    function excludedCount() public view returns (uint256) {
        return _excludedCount;
    }
}