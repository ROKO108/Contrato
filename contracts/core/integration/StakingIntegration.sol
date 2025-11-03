// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../access/ModuleAccess.sol";

/**
 * @title StakingIntegration - Manages staking-related integrations
 * @notice Coordinates staking and reward modules
 */
contract StakingIntegration is ModuleAccess {
    address public immutable stakeManager;
    address public immutable rewardManager;
    
    bytes4 public constant STAKE_ROLE = bytes4(keccak256("STAKE_ROLE"));
    bytes4 public constant REWARD_ROLE = bytes4(keccak256("REWARD_ROLE"));
    
    event StakingUpdated(address indexed user, uint256 amount, bool isStake);
    event RewardClaimed(address indexed user, uint256 amount);
    
    constructor(
        address _stakeManager,
        address _rewardManager
    ) {
        stakeManager = _stakeManager;
        rewardManager = _rewardManager;
        
        authorizeModule(_stakeManager, STAKE_ROLE);
        authorizeModule(_rewardManager, REWARD_ROLE);
    }
    
    function stake(address user, uint256 amount) 
        external 
        onlyAuthorizedModule(STAKE_ROLE) 
    {
        emit StakingUpdated(user, amount, true);
    }
    
    function unstake(address user, uint256 amount) 
        external 
        onlyAuthorizedModule(STAKE_ROLE) 
    {
        emit StakingUpdated(user, amount, false);
    }
    
    function claimReward(address user, uint256 amount) 
        external 
        onlyAuthorizedModule(REWARD_ROLE) 
    {
        emit RewardClaimed(user, amount);
    }
}