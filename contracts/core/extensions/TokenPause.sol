// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/security/Pausable.sol";
import "../access/ModuleAccess.sol";

/**
 * @title TokenPause - Implements pause functionality
 * @notice Allows pausing token transfers in emergency situations
 */
contract TokenPause is Pausable, ModuleAccess {
    bytes4 public constant PAUSE_ROLE = bytes4(keccak256("PAUSE_ROLE"));
    bytes4 public constant UNPAUSE_ROLE = bytes4(keccak256("UNPAUSE_ROLE"));

    constructor(address emergencyModule) {
        authorizeModule(emergencyModule, PAUSE_ROLE);
        authorizeModule(emergencyModule, UNPAUSE_ROLE);
    }

    function pause() external onlyAuthorizedModule(PAUSE_ROLE) {
        _pause();
    }

    function unpause() external onlyAuthorizedModule(UNPAUSE_ROLE) {
        _unpause();
    }
}