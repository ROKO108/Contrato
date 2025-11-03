// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./TokenPermit.sol";

/**
 * @title TokenVotes - Implements voting and delegation logic
 * @notice Adds support for voting and delegation mechanisms
 */
abstract contract TokenVotes is TokenPermit, ERC20Votes {
    constructor(
        string memory name,
        address initialOwner,
        address transferProcessor,
        address transferValidation
    ) 
        TokenPermit(name, initialOwner, transferProcessor, transferValidation)
    {}

    // Override _update to maintain voting power
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(TokenCore, ERC20Votes) {
        super._update(from, to, amount);
    }

    function getVotes(address account) public view virtual override returns (uint256) {
        return super.getVotes(account);
    }

    function getPastVotes(address account, uint256 blockNumber) public view virtual override returns (uint256) {
        return super.getPastVotes(account, blockNumber);
    }
}