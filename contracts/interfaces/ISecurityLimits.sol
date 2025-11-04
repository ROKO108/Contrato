// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ISecurityLimits
 * @notice Interface for security limits and transfer validation
 */
interface ISecurityLimits {
    event SecurityLimitHit(string limitType, address indexed user, uint256 amount);
    event AntiFlashLoanTriggered(address indexed user, uint256 blocksStaked);

    function checkTransferLimit(address from, uint256 amount) external returns (bool);
    function checkFlashLoanProtection(address user, uint256 stakeStartBlock) external view returns (bool);
    function getLastUpdate(address user) external view returns (uint256);
}