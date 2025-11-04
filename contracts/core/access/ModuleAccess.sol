// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../interfaces/IModuleAccess.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ModuleAccess - Controls module permissions and access
 * @notice Manages which modules have access to specific token functionality
 */
contract ModuleAccess is IModuleAccess, Ownable {
    mapping(address => mapping(bytes32 => bool)) private _authorizedModules;
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    modifier onlyAuthorizedModule(bytes32 role) {
        require(_authorizedModules[msg.sender][role], "ModuleAccess: unauthorized");
        _;
    }
    
function authorizeModule(address module, bytes32 role) external override onlyOwner {
        require(module != address(0), "ModuleAccess: zero address");
        _authorizedModules[module][role] = true;
        emit ModuleAuthorized(module, role);
    }
    
    function revokeModule(address module, bytes32 role) external override onlyOwner {
        require(_authorizedModules[module][role], "ModuleAccess: invalid module");
        _authorizedModules[module][role] = false;
        emit ModuleRevoked(module, role);
    }
    
    function isModuleAuthorized(address module, bytes32 role) 
        external 
        view 
        override 
        returns (bool) 
    {
        return _authorizedModules[module][role];
    }
}