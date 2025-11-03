// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "./TokenVotes.sol";

/**
 * @title TokenSnapshot - Implements snapshot functionality
 * @notice Allows creating snapshots of token balances at specific points in time
 */
abstract contract TokenSnapshot is TokenVotes, ERC20Snapshot {
    constructor(
        string memory name,
        address initialOwner,
        address transferProcessor,
        address transferValidation
    ) 
        TokenVotes(name, initialOwner, transferProcessor, transferValidation)
    {}

    // Override _update to handle snapshots
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(TokenVotes, ERC20Snapshot) {
        super._update(from, to, amount);
    }

    /**
     * @notice Creates a new snapshot
     * @return The ID of the newly created snapshot
     */
    function snapshot() external onlyOwner returns (uint256) {
        return _snapshot();
    }

    function getCurrentSnapshotId() external view returns (uint256) {
        return _getCurrentSnapshotId();
    }

    function balanceOfAt(address account, uint256 snapshotId) public view virtual override returns (uint256) {
        return super.balanceOfAt(account, snapshotId);
    }

    function totalSupplyAt(uint256 snapshotId) public view virtual override returns (uint256) {
        return super.totalSupplyAt(snapshotId);
    }
}