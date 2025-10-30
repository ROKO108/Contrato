// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/// @title MyTokenPro: Token profesional con staking, rewards, gobernanza, fee dinámico y mejoras avanzadas
contract MyTokenPro is
    ERC20,
    ERC20Permit,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Votes,
    Ownable2Step,
    ReentrancyGuard
{
    uint256 private immutable MAX_SUPPLY;
    uint256 private _minted;
    address private _treasury;

    mapping(address => bool) private _excludedFromFees;

    uint256 public feePercent;
    uint256 public FEE_MIN = 5;
    uint256 public FEE_MAX = 50;
    uint256 public constant FEE_BASE = 1000;
    uint256 public constant BURN_PERCENT = 20;
    uint256 public constant STAKING_PERCENT = 50;

    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastClaimBlock;
        uint256 lockedUntilBlock;
    }

    mapping(address => StakeInfo) private _stakes;
    uint256 private _totalStaked;
    uint256 private _stakingPool;
    uint256 private _accRewardPerToken;

    uint256 public constant MIN_BLOCKS_BETWEEN_CLAIM = 5;
    uint256 public constant MIN_LOCK_BLOCKS = 20;
    uint256 public constant MAX_CLAIM_PERCENT = 20;

    event Mint(address indexed to, uint256 amount);
    event TreasuryUpdated(address indexed newTreasury);
    event FeeExclusionSet(address indexed account, bool excluded);
    event FeeApplied(
        address indexed from,
        uint256 fee,
        uint256 burn,
        uint256 staking,
        uint256 treasury
    );
    event FeePercentUpdated(uint256 newFeePercent);
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 lockedUntilBlock
    );
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

constructor(
    address initialOwner,
    address treasuryAddress
)
    ERC20("MyTokenPro", "MTP")
    ERC20Permit("MyTokenPro")
    Ownable(initialOwner)
{
    _treasury = treasuryAddress;
    _excludeFromFees(initialOwner, true);
    _excludeFromFees(treasuryAddress, true);

    MAX_SUPPLY = 1_000_000_000 * 10 ** decimals();
    feePercent = 25;
}

    function mint(address to, uint256 amount) external nonReentrant onlyOwner {
        require(_minted + amount <= MAX_SUPPLY, "Max supply exceeded");
        _mint(to, amount);
        _minted += amount;
        emit Mint(to, amount);
    }

    function burn(uint256 amount) public override nonReentrant {
        super.burn(amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Zero address");
        _treasury = newTreasury;
        _excludeFromFees(newTreasury, true);
        emit TreasuryUpdated(newTreasury);
    }

    function setExcludedFromFees(
        address account,
        bool excluded
    ) external onlyOwner {
        _excludeFromFees(account, excluded);
        emit FeeExclusionSet(account, excluded);
    }

    function setFeeRange(uint256 minFee, uint256 maxFee) external onlyOwner {
        require(minFee <= maxFee, "Invalid range");
        FEE_MIN = minFee;
        FEE_MAX = maxFee;
    }

    function _updateFee() internal {
        if (totalSupply() == 0) return;
        uint256 poolRatio = (_stakingPool * 1e18) / totalSupply();
        uint256 dynamicFee = FEE_MAX - ((FEE_MAX - FEE_MIN) * poolRatio) / 1e18;
        if (dynamicFee < FEE_MIN) dynamicFee = FEE_MIN;
        if (dynamicFee > FEE_MAX) dynamicFee = FEE_MAX;
        feePercent = dynamicFee;
        emit FeePercentUpdated(dynamicFee);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable, ERC20Votes) {
        require(!paused(), "Token transfer while paused");

        _updateFee();

        if (
            _excludedFromFees[from] ||
            _excludedFromFees[to] ||
            from == address(0) ||
            to == address(0)
        ) {
            super._update(from, to, amount);
        } else {
            uint256 fee = (amount * feePercent) / FEE_BASE;
            uint256 burnAmount = (fee * BURN_PERCENT) / 100;
            uint256 stakingAmount = (fee * STAKING_PERCENT) / 100;
            uint256 treasuryAmount = fee - burnAmount - stakingAmount;
            uint256 amountAfterFee = amount - fee;

            if (burnAmount > 0) _burn(from, burnAmount);
            if (stakingAmount > 0) _stakingPool += stakingAmount;
            if (treasuryAmount > 0)
                super._update(from, _treasury, treasuryAmount);
            super._update(from, to, amountAfterFee);

            _updateRewards(from);
            _updateRewards(to);
            emit FeeApplied(
                from,
                fee,
                burnAmount,
                stakingAmount,
                treasuryAmount
            );
        }
    }

    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Zero amount");
        _updateRewards(msg.sender);
        _transfer(msg.sender, address(this), amount);
        StakeInfo storage s = _stakes[msg.sender];
        s.amount += amount;
        s.lockedUntilBlock = block.number + MIN_LOCK_BLOCKS;
        s.lastClaimBlock = block.number;
        _totalStaked += amount;
        emit Staked(msg.sender, amount, s.lockedUntilBlock);
    }

    function unstake(uint256 amount) external nonReentrant whenNotPaused {
        StakeInfo storage s = _stakes[msg.sender];
        require(amount > 0 && s.amount >= amount, "Invalid amount");
        require(block.number >= s.lockedUntilBlock, "Still locked");
        _updateRewards(msg.sender);
        s.amount -= amount;
        _totalStaked -= amount;
        _transfer(address(this), msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function claimReward() external nonReentrant whenNotPaused {
        StakeInfo storage s = _stakes[msg.sender];
        require(
            block.number >= s.lastClaimBlock + MIN_BLOCKS_BETWEEN_CLAIM,
            "Too soon"
        );
        _updateRewards(msg.sender);
        uint256 reward = s.rewardDebt;
        require(reward > 0, "No reward");
        uint256 maxClaim = (_stakingPool * MAX_CLAIM_PERCENT) / 100;
        if (reward > maxClaim) reward = maxClaim;
        if (reward > _stakingPool) reward = _stakingPool;
        _stakingPool -= reward;
        s.rewardDebt -= reward;
        s.lastClaimBlock = block.number;
        _transfer(address(this), msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }

    function _updateRewards(address user) internal {
        if (_totalStaked == 0 || _stakingPool == 0) return;
        _accRewardPerToken = (_stakingPool * 1e18) / _totalStaked;
        StakeInfo storage s = _stakes[user];
        if (s.amount > 0) {
            uint256 pending = (s.amount * _accRewardPerToken) / 1e18 -
                s.rewardDebt;
            s.rewardDebt += pending;
        }
    }

    function stakedBalance(address user) external view returns (uint256) {
        return _stakes[user].amount;
    }

    function totalStaked() external view returns (uint256) {
        return _totalStaked;
    }

    function stakingPool() external view returns (uint256) {
        return _stakingPool;
    }

    function isExcludedFromFees(address account) external view returns (bool) {
        return _excludedFromFees[account];
    }

    function maxSupply() external view returns (uint256) {
        return MAX_SUPPLY;
    }

    function totalMinted() external view returns (uint256) {
        return _minted;
    }

    function treasury() external view returns (address) {
        return _treasury;
    }

    function _excludeFromFees(address account, bool excluded) private {
        _excludedFromFees[account] = excluded;
    }

    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
