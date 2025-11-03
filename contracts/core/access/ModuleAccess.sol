// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../interfaces/IModuleAccess.sol";

/**
 * @title ModuleAccess - Controls module permissions and access
 * @notice Manages which modules have access to specific token functionality
 */
contract ModuleAccess is IModuleAccess {
    mapping(address => bool) private _authorizedModules;
    mapping(bytes4 => address) private _functionModules;
    
    event ModuleAuthorized(address indexed module, bytes4 indexed functionSig);
    event ModuleRevoked(address indexed module, bytes4 indexed functionSig);
    
    modifier onlyAuthorizedModule(bytes4 functionSig) {
        require(_functionModules[functionSig] == msg.sender, "ModuleAccess: unauthorized");
        _;
    }
    
    function authorizeModule(address module, bytes4 functionSig) external override {
        require(module != address(0), "ModuleAccess: zero address");
        _authorizedModules[module] = true;
        _functionModules[functionSig] = module;
        emit ModuleAuthorized(module, functionSig);
    }
    
    function revokeModule(address module, bytes4 functionSig) external override {
        require(_functionModules[functionSig] == module, "ModuleAccess: invalid module");
        _authorizedModules[module] = false;
        delete _functionModules[functionSig];
        emit ModuleRevoked(module, functionSig);
    }
    
    function isAuthorizedModule(address module, bytes4 functionSig) 
        external 
        view 
        override 
        returns (bool) 
    {
        return _authorizedModules[module] && _functionModules[functionSig] == module;
    }
}