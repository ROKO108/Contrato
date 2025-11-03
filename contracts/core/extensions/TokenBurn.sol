// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./TokenSnapshot.sol";

/**
 * @title TokenBurn - Implements burn functionality
 * @notice Allows token holders to burn their tokens
 */
abstract contract TokenBurn is TokenSnapshot, ERC20Burnable {
    event BurnCompleted(address indexed burner, uint256 amount);
    
    constructor(
        string memory name,
        address initialOwner,
        address transferProcessor,
        address transferValidation
    ) 
        TokenSnapshot(name, initialOwner, transferProcessor, transferValidation)
    {}
    
    function burn(uint256 amount) public virtual override {
        require(amount > 0, "TokenBurn: cannot burn 0 tokens");
        super.burn(amount);
        emit BurnCompleted(_msgSender(), amount);
    }
    
    function burnFrom(address account, uint256 amount) public virtual override {
        require(amount > 0, "TokenBurn: cannot burn 0 tokens");
        super.burnFrom(account, amount);
        emit BurnCompleted(account, amount);
    }
}