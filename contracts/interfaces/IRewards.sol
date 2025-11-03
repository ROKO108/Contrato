// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IRewards {
    struct EpochData {
        uint256 accRewardPerToken;
        uint256 startBlock;
        uint256 totalDistributed;
        bool settled;
    }

    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsUpdated(
        address indexed user,
        uint256 pendingReward,
        uint256 accRewardPerToken,
        uint256 timestamp
    );
    event EpochAdvanced(uint256 indexed newEpoch, uint256 startBlock);
    event EpochSettled(uint256 indexed epoch, uint256 totalSettled);

    function claimReward() external;
    function pendingReward(address user) external view returns (uint256);
    function currentEpoch() external view returns (uint256);
    function epochInfo(uint256 epochId) external view returns (
        uint256 accRewardPerToken,
        uint256 startBlock,
        uint256 totalDistributed,
        bool settled
    );
}