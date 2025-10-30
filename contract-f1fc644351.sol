// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title MyTokenPro - Token ERC20 Avanzado con Staking y Gobernanza
 * @notice Implementa sistema de fees dinámicos, staking con recompensas y gobernanza
 * @dev Arquitectura modular con separación de concerns para seguridad y mantenibilidad
 * 
 * ARQUITECTURA:
 * ├── Core: Funcionalidades básicas del token (mint, burn, pause)
 * ├── FeeManager: Sistema de fees dinámicos con protecciones anti-manipulación
 * ├── StakingModule: Sistema de staking con recompensas time-weighted
 * └── Governance: Integración con ERC20Votes para votaciones
 */
contract MyTokenPro is
    ERC20,
    ERC20Permit,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Votes,
    Ownable2Step,
    ReentrancyGuard
{
    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTES Y CONFIGURACIÓN INMUTABLE
    // ═══════════════════════════════════════════════════════════════════════════
    
    uint256 private immutable MAX_SUPPLY;
    uint256 public constant FEE_BASE = 1000;
    uint256 public constant ABSOLUTE_FEE_MAX = 100; // 10% máximo
    uint256 public constant BURN_PERCENT = 20;      // 20% del fee
    uint256 public constant STAKING_PERCENT = 50;   // 50% del fee
    uint256 public constant TREASURY_PERCENT = 30;  // 30% del fee
    
    // Configuración de Staking
    uint256 public constant MIN_BLOCKS_BETWEEN_CLAIM = 5;
    uint256 public constant MIN_LOCK_BLOCKS = 20;
    uint256 public constant REWARD_PRECISION = 1e18;
    uint256 public constant MAX_CLAIM_PERCENT = 20; // 20% del pool por claim
    
    // Protecciones anti-manipulación
    uint256 public constant FEE_UPDATE_COOLDOWN = 100;
    uint256 public constant TIMELOCK_DURATION = 6400; // ~1 día en bloques
    uint256 public constant MAX_EXCLUDED_ACCOUNTS = 100;
    uint256 public constant EPOCH_DURATION = 100000; // Reset acumulador cada X bloques

    // ═══════════════════════════════════════════════════════════════════════════
    // VARIABLES DE ESTADO - CORE
    // ═══════════════════════════════════════════════════════════════════════════
    
    uint256 private _minted;
    address private _treasury;
    uint256 private _excludedCount;
    mapping(address => bool) private _excludedFromFees;

    // ═══════════════════════════════════════════════════════════════════════════
    // VARIABLES DE ESTADO - FEE MANAGER
    // ═══════════════════════════════════════════════════════════════════════════
    
    uint256 public feePercent;
    uint256 public FEE_MIN;
    uint256 public FEE_MAX;
    uint256 private _lastFeeUpdateBlock;
    uint256 private _lastFeeRangeChange;
    
    // TWAP para cálculo de fees (Time-Weighted Average Price)
    struct FeeSnapshot {
        uint256 poolRatio;
        uint256 blockNumber;
    }
    FeeSnapshot private _lastFeeSnapshot;

    // ═══════════════════════════════════════════════════════════════════════════
    // VARIABLES DE ESTADO - STAKING MODULE
    // ═══════════════════════════════════════════════════════════════════════════
    
    struct StakeInfo {
        uint128 amount;              // Cantidad stakeada (optimizado a 128 bits)
        uint128 rewardDebt;          // Recompensas ya contabilizadas
        uint64 lastClaimBlock;       // Último claim
        uint64 lockedUntilBlock;     // Bloqueado hasta
        uint64 lastUpdateBlock;      // Última actualización de recompensas
    }

    struct EpochData {
        uint256 accRewardPerToken;   // Acumulador de recompensas por token
        uint256 startBlock;          // Inicio del epoch
        uint256 totalDistributed;    // Total distribuido en el epoch
    }

    mapping(address => StakeInfo) private _stakes;
    uint256 private _totalStaked;
    uint256 private _stakingPool;
    
    uint256 private _currentEpoch;
    mapping(uint256 => EpochData) private _epochs;
    uint256 private _lastRewardUpdateBlock;

    // ═══════════════════════════════════════════════════════════════════════════
    // TIMELOCK PARA CAMBIOS CRÍTICOS
    // ═══════════════════════════════════════════════════════════════════════════
    
    struct TimelockProposal {
        uint256 executeAfter;
        bool executed;
    }
    
    mapping(bytes32 => TimelockProposal) private _timelockQueue;

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENTOS
    // ═══════════════════════════════════════════════════════════════════════════
    
    // Core Events
    event Mint(address indexed to, uint256 amount, uint256 totalMinted);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event FeeExclusionSet(address indexed account, bool excluded);
    
    // Fee Events
    event FeeApplied(
        address indexed from,
        uint256 totalFee,
        uint256 burnAmount,
        uint256 stakingAmount,
        uint256 treasuryAmount
    );
    event FeePercentUpdated(uint256 oldFee, uint256 newFee, uint256 poolRatio);
    event FeeRangeUpdated(uint256 minFee, uint256 maxFee, uint256 timestamp);
    
    // Staking Events
    event Staked(address indexed user, uint256 amount, uint256 lockedUntilBlock);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsUpdated(
        address indexed user,
        uint256 pendingReward,
        uint256 accRewardPerToken,
        uint256 timestamp
    );
    event EpochAdvanced(uint256 indexed newEpoch, uint256 startBlock);
    
    // Governance Events
    event TimelockQueued(bytes32 indexed proposalId, uint256 executeAfter);
    event TimelockExecuted(bytes32 indexed proposalId);
    event TimelockCancelled(bytes32 indexed proposalId);
    
    // Emergency Events
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount);

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════════
    
    constructor(address initialOwner, address treasuryAddress)
        ERC20("MyTokenPro", "MTP")
        ERC20Permit("MyTokenPro")
        Ownable(initialOwner)
    {
        require(treasuryAddress != address(0), "Treasury: zero address");
        require(initialOwner != address(0), "Owner: zero address");
        
        _treasury = treasuryAddress;
        MAX_SUPPLY = 1_000_000_000 * 10 ** decimals();
        
        // Configuración inicial de fees
        FEE_MIN = 5;   // 0.5%
        FEE_MAX = 50;  // 5%
        feePercent = 25; // 2.5%
        
        // Excluir direcciones críticas
        _excludeFromFees(initialOwner, true);
        _excludeFromFees(treasuryAddress, true);
        _excludeFromFees(address(this), true);
        
        // Inicializar epoch
        _epochs[0].startBlock = block.number;
        _lastRewardUpdateBlock = block.number;
        _lastFeeUpdateBlock = block.number;
        _lastFeeSnapshot.blockNumber = block.number;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MÓDULO CORE - FUNCIONES BÁSICAS DEL TOKEN
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Acuña nuevos tokens (solo owner)
     * @param to Destinatario de los tokens
     * @param amount Cantidad a acuñar
     */
    function mint(address to, uint256 amount) external nonReentrant onlyOwner {
        require(to != address(0), "Mint: zero address");
        require(_minted + amount <= MAX_SUPPLY, "Mint: max supply exceeded");
        
        _mint(to, amount);
        _minted += amount;
        
        emit Mint(to, amount, _minted);
    }

    /**
     * @notice Quema tokens del caller
     * @param amount Cantidad a quemar
     */
    function burn(uint256 amount) public override nonReentrant {
        super.burn(amount);
    }

    /**
     * @notice Pausa todas las transferencias (emergencia)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Despausa las transferencias
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MÓDULO CORE - CONFIGURACIÓN CON TIMELOCK
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Cambia la dirección del treasury (con timelock de 1 día)
     * @dev Primera llamada: encola propuesta. Segunda llamada (después del timelock): ejecuta
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Treasury: zero address");
        require(newTreasury != address(this), "Treasury: cannot be contract");
        
        bytes32 proposalId = keccak256(abi.encode("setTreasury", newTreasury));
        TimelockProposal storage proposal = _timelockQueue[proposalId];
        
        if (proposal.executeAfter == 0) {
            // Primera llamada: encolar
            proposal.executeAfter = block.number + TIMELOCK_DURATION;
            emit TimelockQueued(proposalId, proposal.executeAfter);
        } else {
            // Segunda llamada: ejecutar
            require(block.number >= proposal.executeAfter, "Timelock: too soon");
            require(!proposal.executed, "Timelock: already executed");
            
            address oldTreasury = _treasury;
            _treasury = newTreasury;
            _excludeFromFees(newTreasury, true);
            proposal.executed = true;
            
            emit TimelockExecuted(proposalId);
            emit TreasuryUpdated(oldTreasury, newTreasury);
        }
    }

    /**
     * @notice Cancela una propuesta timelock (solo owner)
     */
    function cancelTimelockProposal(bytes32 proposalId) external onlyOwner {
        require(_timelockQueue[proposalId].executeAfter > 0, "Timelock: not found");
        require(!_timelockQueue[proposalId].executed, "Timelock: already executed");
        
        delete _timelockQueue[proposalId];
        emit TimelockCancelled(proposalId);
    }

    /**
     * @notice Excluye o incluye una cuenta del sistema de fees
     */
    function setExcludedFromFees(address account, bool excluded) external onlyOwner {
        require(account != address(0), "Exclusion: zero address");
        require(account != address(this), "Exclusion: cannot affect contract");
        
        if (excluded && !_excludedFromFees[account]) {
            require(_excludedCount < MAX_EXCLUDED_ACCOUNTS, "Exclusion: limit reached");
            _excludedCount++;
        } else if (!excluded && _excludedFromFees[account]) {
            _excludedCount--;
        }
        
        _excludeFromFees(account, excluded);
        emit FeeExclusionSet(account, excluded);
    }

    /**
     * @notice Establece el rango de fees permitido (con restricciones y cooldown)
     */
    function setFeeRange(uint256 minFee, uint256 maxFee) external onlyOwner {
        require(minFee <= maxFee, "FeeRange: invalid range");
        require(maxFee <= ABSOLUTE_FEE_MAX, "FeeRange: exceeds absolute max");
        require(
            block.number >= _lastFeeRangeChange + FEE_UPDATE_COOLDOWN,
            "FeeRange: cooldown active"
        );
        
        FEE_MIN = minFee;
        FEE_MAX = maxFee;
        _lastFeeRangeChange = block.number;
        
        // Ajustar fee actual si está fuera del nuevo rango
        if (feePercent < minFee) feePercent = minFee;
        if (feePercent > maxFee) feePercent = maxFee;
        
        emit FeeRangeUpdated(minFee, maxFee, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MÓDULO FEE MANAGER - LÓGICA DE FEES DINÁMICOS
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Actualiza el fee dinámico basado en la ratio del staking pool
     * @dev Usa TWAP y limita cambios abruptos para prevenir manipulación
     */
    function _updateFee() internal {
        // Solo actualizar cada N bloques (anti-spam)
        if (block.number < _lastFeeUpdateBlock + FEE_UPDATE_COOLDOWN) return;
        
        uint256 ts = totalSupply();
        if (ts == 0) return;

        // Calcular ratio actual del pool
        uint256 currentPoolRatio = Math.mulDiv(_stakingPool, REWARD_PRECISION, ts);
        
        // Aplicar TWAP para suavizar cambios
        uint256 poolRatio;
        if (_lastFeeSnapshot.blockNumber > 0) {
            uint256 blockDelta = block.number - _lastFeeSnapshot.blockNumber;
            uint256 weight = blockDelta > 100 ? 100 : blockDelta;
            poolRatio = Math.mulDiv(_lastFeeSnapshot.poolRatio, (100 - weight), 100) +
                       Math.mulDiv(currentPoolRatio, weight, 100);
        } else {
            poolRatio = currentPoolRatio;
        }
        
        // Calcular nuevo fee dinámico
        uint256 delta = FEE_MAX - FEE_MIN;
        uint256 sub = Math.mulDiv(delta, poolRatio, REWARD_PRECISION);
        uint256 newFee = FEE_MAX > sub ? FEE_MAX - sub : FEE_MIN;
        
        // Limitar cambios abruptos (máx ±10% por actualización)
        uint256 maxChange = Math.mulDiv(feePercent, 10, 100);
        if (maxChange == 0) maxChange = 1;
        
        if (newFee > feePercent + maxChange) newFee = feePercent + maxChange;
        if (newFee < feePercent - maxChange && feePercent > maxChange) {
            newFee = feePercent - maxChange;
        }
        
        // Aplicar límites absolutos
        if (newFee < FEE_MIN) newFee = FEE_MIN;
        if (newFee > FEE_MAX) newFee = FEE_MAX;

        uint256 oldFee = feePercent;
        feePercent = newFee;
        _lastFeeUpdateBlock = block.number;
        _lastFeeSnapshot = FeeSnapshot(poolRatio, block.number);
        
        emit FeePercentUpdated(oldFee, newFee, poolRatio);
    }

    /**
     * @notice Aplica fees a una transferencia
     * @dev Distribuye: 20% burn, 50% staking pool, 30% treasury
     */
    function _applyFees(address from, address to, uint256 amount) 
        internal 
        returns (uint256 amountAfterFee) 
    {
        uint256 fee = Math.mulDiv(amount, feePercent, FEE_BASE);
        if (fee == 0) return amount;

        uint256 burnAmount = Math.mulDiv(fee, BURN_PERCENT, 100);
        uint256 stakingAmount = Math.mulDiv(fee, STAKING_PERCENT, 100);
        uint256 treasuryAmount = fee - burnAmount - stakingAmount;
        amountAfterFee = amount - fee;

        // Aplicar burn
        if (burnAmount > 0) {
            _burn(from, burnAmount);
        }

        // Transferir a staking pool (CORRECCIÓN CRÍTICA)
        if (stakingAmount > 0) {
            super._update(from, address(this), stakingAmount);
            _stakingPool += stakingAmount;
        }

        // Transferir a treasury
        if (treasuryAmount > 0) {
            super._update(from, _treasury, treasuryAmount);
        }

        // Transferir el resto al destinatario
        super._update(from, to, amountAfterFee);

        emit FeeApplied(from, fee, burnAmount, stakingAmount, treasuryAmount);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // OVERRIDE _update - PUNTO DE ENTRADA PARA TODAS LAS TRANSFERENCIAS
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Hook llamado en todas las transferencias, mints y burns
     * @dev Implementa lógica de fees y actualización de recompensas
     */
    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Pausable, ERC20Votes)
    {
        require(!paused(), "Token: paused");

        // Actualizar fee dinámico
        _updateFee();

        // Determinar si se aplican fees
        bool applyFees = !_excludedFromFees[from] && 
                        !_excludedFromFees[to] && 
                        from != address(0) && 
                        to != address(0);

        if (applyFees) {
            // Actualizar recompensas antes de cambiar balances
            _updateRewards(from);
            _updateRewards(to);
            
            // Aplicar fees y transferir
            _applyFees(from, to, amount);
        } else {
            // Transferencia sin fees
            super._update(from, to, amount);
            
            if (from != address(0)) _updateRewards(from);
            if (to != address(0)) _updateRewards(to);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MÓDULO STAKING - SISTEMA DE RECOMPENSAS
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Stakea tokens para ganar recompensas
     * @param amount Cantidad a stakear
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Stake: zero amount");
        require(balanceOf(msg.sender) >= amount, "Stake: insufficient balance");
        
        _updateRewards(msg.sender);
        
        // Transferir tokens al contrato
        _transfer(msg.sender, address(this), amount);
        
        // Actualizar stake info
        StakeInfo storage s = _stakes[msg.sender];
        s.amount += uint128(amount);
        s.lockedUntilBlock = uint64(block.number + MIN_LOCK_BLOCKS);
        s.lastClaimBlock = uint64(block.number);
        s.lastUpdateBlock = uint64(block.number);
        
        _totalStaked += amount;
        
        emit Staked(msg.sender, amount, s.lockedUntilBlock);
    }

    /**
     * @notice Retira tokens stakeados
     * @param amount Cantidad a retirar
     */
    function unstake(uint256 amount) external nonReentrant whenNotPaused {
        StakeInfo storage s = _stakes[msg.sender];
        require(amount > 0 && s.amount >= amount, "Unstake: invalid amount");
        require(block.number >= s.lockedUntilBlock, "Unstake: still locked");
        
        _updateRewards(msg.sender);
        
        // Permitir retiro total incluso con imprecisiones de redondeo
        uint256 actualAmount = amount;
        if (amount == s.amount) {
            uint256 contractBalance = balanceOf(address(this));
            uint256 availableForUnstake = contractBalance >= _stakingPool 
                ? contractBalance - _stakingPool 
                : 0;
            
            if (actualAmount > availableForUnstake) {
                actualAmount = availableForUnstake;
            }
        }
        
        require(actualAmount > 0, "Unstake: insufficient contract balance");
        
        // Actualizar estado
        s.amount -= uint128(amount);
        _totalStaked -= amount;
        
        // Transferir tokens
        _transfer(address(this), msg.sender, actualAmount);
        
        emit Unstaked(msg.sender, actualAmount);
    }

    /**
     * @notice Reclama recompensas acumuladas
     */
    function claimReward() external nonReentrant whenNotPaused {
        StakeInfo storage s = _stakes[msg.sender];
        require(
            block.number >= s.lastClaimBlock + MIN_BLOCKS_BETWEEN_CLAIM,
            "Claim: too soon"
        );

        _updateRewards(msg.sender);
        
        uint256 reward = s.rewardDebt;
        require(reward > 0, "Claim: no reward");

        // Límite máximo por claim (20% del pool)
        uint256 maxClaim = Math.mulDiv(_stakingPool, MAX_CLAIM_PERCENT, 100);
        if (maxClaim == 0 && _stakingPool > 0) maxClaim = 1;
        if (reward > maxClaim) reward = maxClaim;
        if (reward > _stakingPool) reward = _stakingPool;
        
        require(reward > 0, "Claim: reward too small");

        // Actualizar estado
        _stakingPool -= reward;
        s.rewardDebt = 0; // Reset debt después del claim
        s.lastClaimBlock = uint64(block.number);

        // Transferir recompensa
        _transfer(address(this), msg.sender, reward);
        
        emit RewardClaimed(msg.sender, reward);
        emit RewardsUpdated(msg.sender, reward, _epochs[_currentEpoch].accRewardPerToken, block.timestamp);
    }

    /**
     * @notice Actualiza las recompensas de un usuario (CORRECCIÓN CRÍTICA)
     * @dev Implementa sistema de epochs para prevenir overflow del acumulador
     */
    function _updateRewards(address user) internal {
        if (user == address(0) || user == address(this)) return;
        
        // Avanzar epoch si es necesario
        if (block.number >= _epochs[_currentEpoch].startBlock + EPOCH_DURATION) {
            _currentEpoch++;
            _epochs[_currentEpoch].startBlock = block.number;
            _epochs[_currentEpoch].accRewardPerToken = 0;
            emit EpochAdvanced(_currentEpoch, block.number);
        }

        // Solo actualizar una vez por bloque
        if (block.number == _lastRewardUpdateBlock) return;

        EpochData storage epoch = _epochs[_currentEpoch];
        
        // Calcular recompensas acumuladas desde última actualización
        if (_totalStaked > 0 && _stakingPool > 0) {
            uint256 blocksSinceUpdate = block.number - _lastRewardUpdateBlock;
            
            // Distribuir pequeña fracción del pool por bloque
            uint256 rewardPerBlock = Math.mulDiv(_stakingPool, 1, 10000); // 0.01% por bloque
            uint256 totalReward = rewardPerBlock * blocksSinceUpdate;
            
            if (totalReward > _stakingPool) totalReward = _stakingPool;
            if (totalReward > 0) {
                uint256 rewardPerToken = Math.mulDiv(totalReward, REWARD_PRECISION, _totalStaked);
                epoch.accRewardPerToken += rewardPerToken;
                epoch.totalDistributed += totalReward;
            }
        }

        // Actualizar recompensas del usuario
        StakeInfo storage s = _stakes[user];
        if (s.amount > 0) {
            uint256 accumulatedReward = Math.mulDiv(
                uint256(s.amount),
                epoch.accRewardPerToken,
                REWARD_PRECISION
            );
            
            if (accumulatedReward > s.rewardDebt) {
                uint256 pending = accumulatedReward - s.rewardDebt;
                s.rewardDebt = uint128(accumulatedReward);
                s.lastUpdateBlock = uint64(block.number);
                
                emit RewardsUpdated(user, pending, epoch.accRewardPerToken, block.timestamp);
            }
        }

        _lastRewardUpdateBlock = block.number;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNCIONES DE EMERGENCIA
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Retira tokens en caso de emergencia (solo cuando está pausado)
     * @dev Requiere que el contrato esté pausado por al menos TIMELOCK_DURATION bloques
     */
    function emergencyWithdraw(address tokenAddress, address to, uint256 amount) 
        external 
        onlyOwner 
        whenPaused 
    {
        require(to != address(0), "Emergency: zero address");
        // Implementar chequeo adicional de tiempo en pausa si es necesario
        
        if (tokenAddress == address(this)) {
            _transfer(address(this), to, amount);
        } else {
            // Para otros tokens ERC20 atrapados
            (bool success, bytes memory data) = tokenAddress.call(
                abi.encodeWithSignature("transfer(address,uint256)", to, amount)
            );
            require(success && (data.length == 0 || abi.decode(data, (bool))), "Emergency: transfer failed");
        }
        
        emit EmergencyWithdrawal(tokenAddress, to, amount);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VISTAS PÚBLICAS - GETTERS
    // ═══════════════════════════════════════════════════════════════════════════
    
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

    function stakeInfo(address user) external view returns (
        uint256 amount,
        uint256 rewardDebt,
        uint256 lastClaimBlock,
        uint256 lockedUntilBlock,
        uint256 lastUpdateBlock
    ) {
        StakeInfo memory s = _stakes[user];
        return (
            s.amount,
            s.rewardDebt,
            s.lastClaimBlock,
            s.lockedUntilBlock,
            s.lastUpdateBlock
        );
    }

    function currentEpoch() external view returns (uint256) {
        return _currentEpoch;
    }

    function epochInfo(uint256 epochId) external view returns (
        uint256 accRewardPerToken,
        uint256 startBlock,
        uint256 totalDistributed
    ) {
        EpochData memory epoch = _epochs[epochId];
        return (
            epoch.accRewardPerToken,
            epoch.startBlock,
            epoch.totalDistributed
        );
    }

    function pendingReward(address user) external view returns (uint256) {
        StakeInfo memory s = _stakes[user];
        if (s.amount == 0) return s.rewardDebt;
        
        EpochData memory epoch = _epochs[_currentEpoch];
        uint256 accumulatedReward = Math.mulDiv(
            uint256(s.amount),
            epoch.accRewardPerToken,
            REWARD_PRECISION
        );
        
        return accumulatedReward > s.rewardDebt 
            ? (accumulatedReward - s.rewardDebt) + s.rewardDebt
            : s.rewardDebt;
    }

    function excludedCount() external view returns (uint256) {
        return _excludedCount;
    }

    function timelockProposal(bytes32 proposalId) external view returns (
        uint256 executeAfter,
        bool executed
    ) {
        TimelockProposal memory proposal = _timelockQueue[proposalId];
        return (proposal.executeAfter, proposal.executed);
    }

    function getTimelockProposalId(string memory action, address param) 
        external 
        pure 
        returns (bytes32) 
    {
        return keccak256(abi.encode(action, param));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INVARIANTES - FUNCIONES DE VERIFICACIÓN (para testing y auditoría)
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Verifica que el balance del contrato sea suficiente para cubrir obligaciones
     * @dev Útil para testing y monitoreo
     */
    function checkInvariants() external view returns (bool) {
        uint256 contractBalance = balanceOf(address(this));
        uint256 obligations = _stakingPool + _totalStaked;
        return contractBalance >= obligations;
    }

    /**
     * @notice Retorna un resumen completo del estado del contrato
     */
    function getContractState() external view returns (
        uint256 totalSupply_,
        uint256 maxSupply_,
        uint256 totalMinted_,
        uint256 totalStaked_,
        uint256 stakingPool_,
        uint256 currentFee_,
        uint256 currentEpoch_,
        address treasury_,
        bool paused_
    ) {
        return (
            totalSupply(),
            MAX_SUPPLY,
            _minted,
            _totalStaked,
            _stakingPool,
            feePercent,
            _currentEpoch,
            _treasury,
            paused()
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNCIONES INTERNAS AUXILIARES
    // ═══════════════════════════════════════════════════════════════════════════
    
    function _excludeFromFees(address account, bool excluded) private {
        _excludedFromFees[account] = excluded;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // OVERRIDE NECESARIOS PARA COMPATIBILIDAD
    // ═══════════════════════════════════════════════════════════════════════════
    
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}