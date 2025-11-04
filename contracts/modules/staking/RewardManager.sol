// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../interfaces/IRewards.sol";
import "../../libraries/MathUtils.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title RewardManager
 * @dev Gestión de recompensas y epochs
 */
contract RewardManager is IRewards, ReentrancyGuard {
    using MathUtils for uint256;

    uint256 public constant REWARD_PRECISION = 1e18;
    uint256 public constant MAX_CLAIM_PERCENT = 10;
    uint256 public constant MIN_BLOCKS_BETWEEN_CLAIM = 100;
    uint256 public constant EPOCH_DURATION = 100000;
    uint256 public constant MAX_REWARD_PER_UPDATE = 100;

    mapping(address => uint256) private _lastUserUpdate;
    mapping(uint256 => EpochData) private _epochs;
    uint256 private _currentEpoch;
    uint256 private _lastRewardUpdateBlock;

    IERC20 private immutable _token;
    address private immutable _stakingContract;

    constructor(address token_, address stakingContract_) {
        require(token_ != address(0) && stakingContract_ != address(0), "Invalid address");
        _token = IERC20(token_);
        _stakingContract = stakingContract_;
        
        _epochs[0].startBlock = block.number;
        _lastRewardUpdateBlock = block.number;
    }

    modifier onlyStakingContract() {
        require(msg.sender == _stakingContract, "Only staking contract");
        _;
    }

    function claimReward() external override nonReentrant {
        require(block.number >= _lastUserUpdate[msg.sender] + MIN_BLOCKS_BETWEEN_CLAIM, "Too soon");

        uint256 reward = pendingReward(msg.sender);
        require(reward > 0, "No reward");

        uint256 maxClaim = MathUtils.calculateRatio(_token.balanceOf(address(this)), MAX_CLAIM_PERCENT, 100);
        if (maxClaim == 0 && _token.balanceOf(address(this)) > 0) maxClaim = 1;
        
        reward = Math.min(reward, maxClaim);
        require(reward > 0, "Reward too small");

        _lastUserUpdate[msg.sender] = block.number;

        bool success = _token.transfer(msg.sender, reward);
        require(success, "Transfer failed");

        emit RewardClaimed(msg.sender, reward);
    }

    function updateRewards(address user) external onlyStakingContract {
        if (block.number <= _lastRewardUpdateBlock) return;

        if (block.number >= _epochs[_currentEpoch].startBlock + EPOCH_DURATION) {
            _settleCurrentEpoch();
            _currentEpoch++;
            _epochs[_currentEpoch].startBlock = block.number;
            emit EpochAdvanced(_currentEpoch, block.number);
        }

        EpochData storage epoch = _epochs[_currentEpoch];
        
        // Actualizar acumulador global
        if (_token.balanceOf(address(this)) > 0) {
            uint256 blocksSinceUpdate = block.number - _lastRewardUpdateBlock;
            uint256 rewardPerBlock = MathUtils.calculateRatio(_token.balanceOf(address(this)), 1, 10000);
            uint256 totalReward = rewardPerBlock * blocksSinceUpdate;

            uint256 maxReward = MathUtils.calculateRatio(
                _token.balanceOf(address(this)),
                MAX_REWARD_PER_UPDATE,
                10000
            );

            totalReward = Math.min(totalReward, maxReward);
            
if (totalReward > 0) {
                uint256 stakingBalance = _token.balanceOf(_stakingContract);
                require(stakingBalance > 0, "Reward: no staking balance");
                
                uint256 rewardPerToken = MathUtils.calculateRatio(
                    totalReward,
                    REWARD_PRECISION,
                    stakingBalance
                );
                
                // Prevent overflow
                require(epoch.accRewardPerToken <= type(uint256).max - rewardPerToken, "Reward: overflow");
                
                epoch.accRewardPerToken += rewardPerToken;
                
                // Prevent overflow in total distributed
                require(epoch.totalDistributed <= type(uint256).max - totalReward, "Reward: total overflow");
                epoch.totalDistributed += totalReward;
            }
        }

        _lastRewardUpdateBlock = block.number;
        
        emit RewardsUpdated(
            user,
            pendingReward(user),
            epoch.accRewardPerToken,
            block.timestamp
        );
    }

    function _settleCurrentEpoch() private {
        EpochData storage epoch = _epochs[_currentEpoch];
        if (!epoch.settled) {
            epoch.settled = true;
            emit EpochSettled(_currentEpoch, epoch.totalDistributed);
        }
    }

    // Implementación de vistas de la interfaz
    function pendingReward(address user) public view override returns (uint256) {
        return _epochs[_currentEpoch].accRewardPerToken;
    }

    function currentEpoch() external view override returns (uint256) {
        return _currentEpoch;
    }

    function epochInfo(uint256 epochId) external view override returns (
        uint256 accRewardPerToken,
        uint256 startBlock,
        uint256 totalDistributed,
        bool settled
    ) {
        EpochData memory epoch = _epochs[epochId];
        return (
            epoch.accRewardPerToken,
            epoch.startBlock,
            epoch.totalDistributed,
            epoch.settled
        );
    }
}