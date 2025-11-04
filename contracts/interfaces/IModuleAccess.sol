// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IModuleAccess
 * @notice Interface for contracts that manage module authorization and roles.
 * This interface is typically implemented by the core token or a dedicated access control contract.
 */
interface IModuleAccess {
    // Events
    event ModuleAuthorized(address indexed module, bytes32 indexed role);
    event ModuleRevoked(address indexed module, bytes32 indexed role);

    // Functions
    function authorizeModule(address module, bytes32 role) external;
    function revokeModule(address module, bytes32 role) external;
    function isModuleAuthorized(address module, bytes32 role) external view returns (bool);
}
