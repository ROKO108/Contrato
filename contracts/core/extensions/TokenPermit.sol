// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "../token/TokenCore.sol";

/**
 * @title TokenPermit - Implements EIP-2612 permit functionality
 * @notice Allows approvals to be made via signatures
 */
abstract contract TokenPermit is TokenCore, ERC20Permit {
    constructor(
        string memory name,
        address initialOwner,
        address transferProcessor,
        address transferValidation
    ) 
        TokenCore(name, name, initialOwner, transferProcessor, transferValidation)
        ERC20Permit(name)
    {}

    // Forward nonces to parent implementation
    function nonces(address owner) 
        public 
        view 
        virtual 
        override(ERC20Permit, Nonces) 
        returns (uint256) 
    {
        return super.nonces(owner);
    }
}