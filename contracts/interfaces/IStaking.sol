// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IStaking {
    struct StakeInfo {
        uint128 amount;
        uint64 stakeStartBlock;
        uint64 lastClaimBlock;
        uint128 rewardDebt;
        uint64 lockedUntilBlock;
        uint64 lastUpdateBlock;
    }

    event Staked(
        address indexed user,
        uint256 amount,
        uint256 lockedUntilBlock,
        uint256 stakeStartBlock
    );
    event Unstaked(address indexed user, uint256 amount);
    event AntiFlashLoanTriggered(address indexed user, uint256 blocksStaked);

    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function stakedBalance(address user) external view returns (uint256);
    function totalStaked() external view returns (uint256);
    function stakingPool() external view returns (uint256);
    function canClaimReward(address user) external view returns (
        bool canClaim,
        string memory reason,
        uint256 blocksUntilEligible
    );
}