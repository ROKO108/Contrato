// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title TransferHooks - Implements pre and post transfer hooks
 * @notice Manages transfer lifecycle hooks for extended functionality
 */
contract TransferHooks {
    // Array of hook contracts to call before transfers
    address[] private _preTransferHooks;
    // Array of hook contracts to call after transfers
    address[] private _postTransferHooks;
    
    event HookAdded(address indexed hook, bool isPre);
    event HookRemoved(address indexed hook, bool isPre);
    event HookExecuted(address indexed hook, bool isPre, bool success);
    
    function addPreTransferHook(address hook) external {
        _preTransferHooks.push(hook);
        emit HookAdded(hook, true);
    }
    
    function addPostTransferHook(address hook) external {
        _postTransferHooks.push(hook);
        emit HookAdded(hook, false);
    }
    
    function executePreTransferHooks(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        for (uint256 i = 0; i < _preTransferHooks.length; i++) {
            bool success = ITransferHook(_preTransferHooks[i]).beforeTransfer(from, to, amount);
            emit HookExecuted(_preTransferHooks[i], true, success);
            if (!success) return false;
        }
        return true;
    }
    
    function executePostTransferHooks(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        for (uint256 i = 0; i < _postTransferHooks.length; i++) {
            bool success = ITransferHook(_postTransferHooks[i]).afterTransfer(from, to, amount);
            emit HookExecuted(_postTransferHooks[i], false, success);
            if (!success) return false;
        }
        return true;
    }
}