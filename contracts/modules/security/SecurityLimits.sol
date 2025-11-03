// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../libraries/MathUtils.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title SecurityLimits
 * @dev Módulo de límites y protecciones
 */
contract SecurityLimits {
    using MathUtils for uint256;

    uint256 public constant MAX_TRANSFER_PERCENT = 5;
    uint256 public constant USER_UPDATE_COOLDOWN = 10;

    event SecurityLimitHit(string limitType, address indexed user, uint256 amount);
    event AntiFlashLoanTriggered(address indexed user, uint256 blocksStaked);

    mapping(address => uint256) private _lastUpdate;
    IERC20 private immutable _token;

    constructor(address token_) {
        require(token_ != address(0), "Invalid token");
        _token = IERC20(token_);
    }

    function checkTransferLimit(
        address from,
        uint256 amount
    ) external returns (bool) {
        if (block.number < _lastUpdate[from] + USER_UPDATE_COOLDOWN) {
            emit SecurityLimitHit("UpdateCooldown", from, block.number - _lastUpdate[from]);
            return false;
        }

        uint256 maxTransfer = MathUtils.calculateRatio(
            _token.totalSupply(),
            MAX_TRANSFER_PERCENT,
            100
        );

        if (amount > maxTransfer) {
            emit SecurityLimitHit("MaxTransfer", from, amount);
            return false;
        }

        _lastUpdate[from] = block.number;
        return true;
    }

    function checkFlashLoanProtection(
        address user,
        uint256 stakeStartBlock
    ) external view returns (bool) {
        uint256 blocksStaked = block.number - stakeStartBlock;
        if (blocksStaked < USER_UPDATE_COOLDOWN) {
            return false;
        }
        return true;
    }

    function getLastUpdate(address user) external view returns (uint256) {
        return _lastUpdate[user];
    }
}