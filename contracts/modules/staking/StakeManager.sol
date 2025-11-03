// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../interfaces/IStaking.sol";
import "../../libraries/SafetyChecks.sol";
import "../../libraries/ArrayUtils.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title StakeManager
 * @dev Gestión de stakes y límites
 */
contract StakeManager is IStaking, ReentrancyGuard {
    using ArrayUtils for address[];
    
    uint256 public constant MAX_STAKE_AMOUNT = 1_000_000 * 1e18;
    uint256 public constant MIN_LOCK_BLOCKS = 1000;
    uint256 public constant MIN_STAKE_DURATION = 1000;
    uint256 public constant MAX_ACTIVE_STAKERS = 10000;

    mapping(address => StakeInfo) private _stakes;
    mapping(address => bool) private _isActiveStaker;
    address[] private _activeStakers;
    uint256 private _activeStakersCount;
    
    uint256 private _totalStaked;
    uint256 private _stakingPool;

    IERC20 private immutable _token;

    constructor(address token_) {
        SafetyChecks.validateAddress(token_);
        _token = IERC20(token_);
    }

    function stake(uint256 amount) external override nonReentrant {
        SafetyChecks.validateAmount(amount, MAX_STAKE_AMOUNT);
        SafetyChecks.validateBalance(_token.balanceOf(msg.sender), amount);

        StakeInfo storage s = _stakes[msg.sender];
        
        if (s.amount == 0) {
            s.stakeStartBlock = uint64(block.number);
            _addActiveStaker(msg.sender);
        }

        bool success = _token.transferFrom(msg.sender, address(this), amount);
        require(success, "Stake: transfer failed");

        s.amount += uint128(amount);
        s.lockedUntilBlock = uint64(block.number + MIN_LOCK_BLOCKS);
        s.lastClaimBlock = uint64(block.number);
        s.lastUpdateBlock = uint64(block.number);

        _totalStaked += amount;

        emit Staked(msg.sender, amount, s.lockedUntilBlock, s.stakeStartBlock);
    }

    function unstake(uint256 amount) external override nonReentrant {
        StakeInfo storage s = _stakes[msg.sender];
        require(amount > 0 && s.amount >= amount, "Unstake: invalid amount");
        SafetyChecks.validateStakeUnlock(block.number, s.lockedUntilBlock);

        uint256 actualAmount = _calculateUnstakeAmount(amount, s.amount);
        require(actualAmount > 0, "Unstake: insufficient contract balance");

        s.amount -= uint128(amount);
        _totalStaked -= amount;

        if (s.amount == 0) {
            s.stakeStartBlock = 0;
            _removeActiveStaker(msg.sender);
        }

        bool success = _token.transfer(msg.sender, actualAmount);
        require(success, "Unstake: transfer failed");

        emit Unstaked(msg.sender, actualAmount);
    }

    function _calculateUnstakeAmount(uint256 amount, uint256 stakedAmount) private view returns (uint256) {
        if (amount == stakedAmount) {
            uint256 contractBalance = _token.balanceOf(address(this));
            uint256 availableForUnstake = contractBalance >= _stakingPool ? 
                                        contractBalance - _stakingPool : 0;
            return amount > availableForUnstake ? availableForUnstake : amount;
        }
        return amount;
    }

    function _addActiveStaker(address staker) private {
        if (!_isActiveStaker[staker]) {
            require(_activeStakersCount < MAX_ACTIVE_STAKERS, "Max stakers reached");
            _isActiveStaker[staker] = true;
            _activeStakers.push(staker);
            _activeStakersCount++;
        }
    }

    function _removeActiveStaker(address staker) private {
        if (_isActiveStaker[staker]) {
            _isActiveStaker[staker] = false;
            bool removed = _activeStakers.removeAndReplaceWithLast(staker);
            if (removed) {
                _activeStakersCount--;
            }
        }
    }

    // Implementación de vistas de la interfaz
    function stakedBalance(address user) external view override returns (uint256) {
        return _stakes[user].amount;
    }

    function totalStaked() external view override returns (uint256) {
        return _totalStaked;
    }

    function stakingPool() external view override returns (uint256) {
        return _stakingPool;
    }

    function canClaimReward(address user) external view override returns (
        bool canClaim,
        string memory reason,
        uint256 blocksUntilEligible
    ) {
        StakeInfo memory s = _stakes[user];

        if (s.amount == 0) {
            return (false, "No stake", 0);
        }

        uint256 blocksStaked = block.number - s.stakeStartBlock;
        if (blocksStaked < MIN_STAKE_DURATION) {
            return (false, "Insufficient stake duration", MIN_STAKE_DURATION - blocksStaked);
        }

        return (true, "Eligible", 0);
    }
}