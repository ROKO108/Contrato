// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../events/CoreEvents.sol";

/**
 * @title TokenSupply - Manages token supply limits and minting
 * @notice Handles maximum supply constraints and minting controls
 */
abstract contract TokenSupply is CoreEvents {
    uint256 private immutable MAX_SUPPLY = 1_000_000_000 * 1e18;
    uint256 public constant MAX_MINT_PER_CALL = 10_000_000 * 1e18;
    
    uint256 private _minted;
    mapping(address => bool) private _authorizedMinters;
    
    modifier onlyAuthorizedMinter() {
        require(_authorizedMinters[msg.sender], "TokenSupply: unauthorized minter");
        _;
    }
    
    function _authorizeMultipleMinters(address[] memory minters) internal {
        for (uint256 i = 0; i < minters.length; i++) {
            _authorizedMinters[minters[i]] = true;
        }
    }
    
    function _checkMintLimits(uint256 amount) internal view {
        require(amount <= MAX_MINT_PER_CALL, "TokenSupply: max mint per call exceeded");
        require(_minted + amount <= MAX_SUPPLY, "TokenSupply: max supply exceeded");
    }
    
    function _recordMint(address to, uint256 amount) internal {
        _minted += amount;
        emit Mint(to, amount, _minted);
    }
    
    function getTotalMinted() public view returns (uint256) {
        return _minted;
    }
    
    function getMaxSupply() public pure returns (uint256) {
        return MAX_SUPPLY;
    }
    
    function isMinterAuthorized(address minter) public view returns (bool) {
        return _authorizedMinters[minter];
    }
}
}