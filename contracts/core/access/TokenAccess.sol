// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title TokenAccess - Base access control implementation
 * @notice Implements ownership and access control mechanisms
 */
contract TokenAccess is Ownable2Step {
    mapping(bytes4 => bool) private _restrictedFunctions;
    
    event FunctionRestricted(bytes4 indexed functionSig, bool restricted);
    
    constructor(address initialOwner) Ownable2Step(initialOwner);
    
    modifier checkRestriction(bytes4 functionSig) {
        if (_restrictedFunctions[functionSig]) {
            require(owner() == _msgSender(), "TokenAccess: restricted function");
        }
        _;
    }
    
    function restrictFunction(bytes4 functionSig, bool restricted) external onlyOwner {
        _restrictedFunctions[functionSig] = restricted;
        emit FunctionRestricted(functionSig, restricted);
    }
    
    function isFunctionRestricted(bytes4 functionSig) external view returns (bool) {
        return _restrictedFunctions[functionSig];
    }
}