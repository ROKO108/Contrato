// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ModuleEvents - Module-specific events
 * @notice Contains all module-related events used across the system
 */
contract ModuleEvents {
    // Module lifecycle events
    event ModuleInitialized(string moduleType, address indexed module);
    event ModuleUpgraded(
        string moduleType,
        address indexed oldModule,
        address indexed newModule
    );
    event ModuleDisabled(string moduleType, address indexed module);
    
    // Module interaction events
    event ModuleInteraction(
        address indexed module,
        address indexed target,
        bytes4 functionSig,
        bool success
    );
    
    // Module configuration events
    event ModuleConfigurationChanged(
        address indexed module,
        string parameter,
        uint256 oldValue,
        uint256 newValue
    );
    
    // Module permission events
    event ModulePermissionGranted(
        address indexed module,
        bytes4 indexed permission,
        address indexed granter
    );
    event ModulePermissionRevoked(
        address indexed module,
        bytes4 indexed permission,
        address indexed revoker
    );
}