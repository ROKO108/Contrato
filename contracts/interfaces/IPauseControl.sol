// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IPauseControl {
    event SecurityPause(address indexed by, string reason);
    event SecurityUnpause(address indexed by, string reason);

    function pauseWithReason(string memory reason) external;
    function unpauseWithReason(string memory reason) external;
    function isPaused() external view returns (bool);
}