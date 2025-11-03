// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title SafetyChecks
 * @dev Librería de validaciones de seguridad comunes
 */
library SafetyChecks {
    error ZeroAddress();
    error InvalidAmount();
    error ExceedsLimit();
    error InsufficientBalance();
    error StillLocked();
    error TooSoon();

    function validateAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    function validateAmount(uint256 amount, uint256 maxAmount) internal pure {
        if (amount == 0) revert InvalidAmount();
        if (amount > maxAmount) revert ExceedsLimit();
    }

    function validateBalance(uint256 balance, uint256 required) internal pure {
        if (balance < required) revert InsufficientBalance();
    }

    function validateTimestamp(uint256 current, uint256 required) internal pure {
        if (current < required) revert TooSoon();
    }

    function validateStakeUnlock(uint256 currentBlock, uint256 lockedUntil) internal pure {
        if (currentBlock < lockedUntil) revert StillLocked();
    }
}