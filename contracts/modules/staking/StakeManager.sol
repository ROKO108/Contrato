// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../interfaces/IStaking.sol";
import "../../libraries/SafetyChecks.sol";
import "../../libraries/ArrayUtils.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title StakeManager
 * @dev Gestión de stakes y límites
 */
contract StakeManager is IStaking, ReentrancyGuard, Ownable {
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
        // VALIDACIÓN DE INPUTS (Checks)
        SafetyChecks.validateAddress(msg.sender);
        SafetyChecks.validateAmount(amount, MAX_STAKE_AMOUNT);
        SafetyChecks.validateBalance(_token.balanceOf(msg.sender), amount);
        
        // Verificar límite de stakers activos
        StakeInfo storage s = _stakes[msg.sender];
        if (s.amount == 0) {
            require(_activeStakersCount < MAX_ACTIVE_STAKERS, "Stake: max stakers reached");
        }

        // INTERACCIÓN EXTERNA (Interactions) - PRIMERO para tokens ERC20
        // Nota: Para ERC20, el patrón checks-interactions-effects es más seguro
        bool success = _token.transferFrom(msg.sender, address(this), amount);
        require(success, "Stake: transfer failed");

        // ACTUALIZACIÓN DE ESTADO INTERNO (Effects)
        uint64 currentBlock = uint64(block.number);
        
        if (s.amount == 0) {
            s.stakeStartBlock = currentBlock;
            _addActiveStaker(msg.sender);
        }

        s.amount += uint128(amount);
        s.lockedUntilBlock = currentBlock + MIN_LOCK_BLOCKS;
        s.lastClaimBlock = currentBlock;
        s.lastUpdateBlock = currentBlock;

        _totalStaked += amount;

        emit Staked(msg.sender, amount, s.lockedUntilBlock, s.stakeStartBlock);
    }

    function unstake(uint256 amount) external override nonReentrant {
        // VALIDACIÓN DE INPUTS (Checks)
        require(amount > 0, "Unstake: amount must be > 0");
        SafetyChecks.validateAddress(msg.sender);
        
        StakeInfo storage s = _stakes[msg.sender];
        require(s.amount >= amount, "Unstake: insufficient staked amount");
        SafetyChecks.validateStakeUnlock(block.number, s.lockedUntilBlock);
        
        // Anti-flash-loan: verificar duración mínima del stake
        uint256 blocksStaked = block.number - s.stakeStartBlock;
        require(blocksStaked >= MIN_STAKE_DURATION, "Unstake: minimum duration not met");

        // ACTUALIZACIÓN DE ESTADO INTERNO (Effects)
        uint256 actualAmount = _calculateUnstakeAmount(amount, s.amount);
        require(actualAmount > 0, "Unstake: insufficient contract balance");
        
        // Guardar estado anterior para evento
        uint256 previousAmount = s.amount;
        
        // Actualizar estado ANTES de la transferencia externa
        s.amount -= uint128(amount);
        _totalStaked -= amount;
        s.lastUpdateBlock = uint64(block.number);

        if (s.amount == 0) {
            s.stakeStartBlock = 0;
            s.lastClaimBlock = 0;
            _removeActiveStaker(msg.sender);
        }

        // INTERACCIÓN EXTERNA (Interactions) - ÚLTIMO PASO
        bool success = _token.transfer(msg.sender, actualAmount);
        require(success, "Unstake: transfer failed");

        // Emitir evento después de transferencia exitosa
        emit Unstaked(msg.sender, actualAmount);
        
        // Emitir evento anti-flash-loan si es necesario
        if (blocksStaked == MIN_STAKE_DURATION) {
            emit AntiFlashLoanTriggered(msg.sender, blocksStaked);
        }
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
    
    /**
     * @dev Función de emergencia para recuperar tokens enviados por error
     * Solo puede ser llamada por el owner del contrato
     */
    function emergencyRecover(address token, uint256 amount) external onlyOwner {
        require(token != address(_token), "Cannot recover staking token");
        require(amount > 0, "Amount must be > 0");
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(amount <= balance, "Insufficient balance");
        
        bool success = tokenContract.transfer(owner(), amount);
        require(success, "Emergency recovery failed");
    }
    
    /**
     * @dev Verifica si un usuario puede realizar unstake sin vulnerabilidades
     */
    function _validateUnstakeSafety(address user, uint256 amount) private view returns (bool, string memory) {
        if (user == address(0)) return (false, "Invalid user");
        if (amount == 0) return (false, "Invalid amount");
        
        StakeInfo storage s = _stakes[user];
        if (s.amount < amount) return (false, "Insufficient staked amount");
        if (block.number < s.lockedUntilBlock) return (false, "Stake still locked");
        
        uint256 blocksStaked = block.number - s.stakeStartBlock;
        if (blocksStaked < MIN_STAKE_DURATION) return (false, "Minimum duration not met");
        
        return (true, "");
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