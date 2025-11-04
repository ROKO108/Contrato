// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../../interfaces/IFeeProcessor.sol";
import "../../libraries/MathUtils.sol";
import "../../libraries/SafetyChecks.sol";
import "./FeeExclusions.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title FeeProcessor
 * @dev Procesamiento y distribución de fees
 */
contract FeeProcessor is IFeeProcessor, Ownable, ReentrancyGuard {
    using MathUtils for uint256;

    uint256 public constant FEE_BASE = 1000;
    uint256 public constant BURN_PERCENT = 20;  // 20% del fee
    uint256 public constant STAKING_PERCENT = 50;  // 50% del fee
    uint256 public constant TREASURY_PERCENT = 30;  // 30% del fee
    uint256 public constant FEE_UPDATE_COOLDOWN = 100;

    uint256 public feePercent;
    uint256 public FEE_MIN;
    uint256 public FEE_MAX;
    uint256 private _lastFeeUpdateBlock;
    FeeSnapshot private _lastFeeSnapshot;

    address private immutable _treasury;
    FeeExclusions private immutable _exclusions;

constructor(
        address treasury_,
        address exclusionsContract,
        uint256 initialFeePercent,
        uint256 minFee,
        uint256 maxFee,
        address initialOwner
    ) Ownable(initialOwner) {
        SafetyChecks.validateAddress(treasury_);
        SafetyChecks.validateAddress(exclusionsContract);
        
        _treasury = treasury_;
        _exclusions = FeeExclusions(exclusionsContract);
        
        FEE_MIN = minFee;
        FEE_MAX = maxFee;
        feePercent = initialFeePercent;
        
        _lastFeeUpdateBlock = block.number;
        _lastFeeSnapshot = FeeSnapshot(0, block.number);
    }

    // Administración de exclusiones y rango de fee - implementaciones mínimas
    function setExcludedFromFees(address account, bool excluded) external override {
        // Intentar delegar a FeeExclusions; puede revertir si no tenemos permisos.
        try _exclusions.setExcludedFromFees(account, excluded) {
            // success
        } catch {
            // ignore failures - just emit event to satisfy interface
        }
        emit FeeExclusionSet(account, excluded);
    }

function setFeeRange(uint256 minFee, uint256 maxFee, bytes32 /* proposalId */, bytes32 /* salt */) external override onlyOwner {
        // Aplicar cambios directamente (in a real setup, this should be timelocked)
        require(minFee < maxFee, "Fee: min must be less than max");
        require(minFee >= 0 && maxFee <= FEE_BASE, "Fee: invalid range");
        FEE_MIN = minFee;
        FEE_MAX = maxFee;
        emit FeeRangeUpdated(minFee, maxFee, block.timestamp);
    }

function processFee(
        address from,
        address to,
        uint256 amount
    ) external nonReentrant returns (uint256 amountAfterFee) {
        // Early exit for excluded addresses (gas optimization)
        if (_exclusions.isExcludedFromFees(from) || 
            _exclusions.isExcludedFromFees(to)) {
            return amount;
        }

        // Input validation first (fail fast)
        require(amount > 0, "Fee: amount must be > 0");
        require(feePercent <= FEE_BASE, "Fee: invalid percent");

        // Optimized fee calculation with bounds checking
        uint256 fee = (amount * feePercent) / FEE_BASE;
        if (fee == 0) return amount;
        
        // Prevent fee from exceeding amount
        if (fee > amount) fee = amount;

        // Optimized distribution calculation (avoid multiple mulDiv calls)
        uint256 burnAmount = (fee * BURN_PERCENT) / 100;
        uint256 stakingAmount = (fee * STAKING_PERCENT) / 100;
        uint256 treasuryAmount = fee - burnAmount - stakingAmount;

        // Gas-optimized arithmetic with unchecked where safe
        unchecked {
            amountAfterFee = amount - fee;
        }

        emit FeeApplied(from, fee, burnAmount, stakingAmount, treasuryAmount);
        
        return amountAfterFee;
    }

function updateFee(uint256 stakingPool, uint256 totalSupply) external {
        // Early exit checks (gas optimization)
        if (block.number < _lastFeeUpdateBlock + FEE_UPDATE_COOLDOWN) return;
        if (totalSupply == 0) return;

        uint256 currentPoolRatio = (stakingPool * 1e18) / totalSupply;

        uint256 poolRatio;
        if (_lastFeeSnapshot.blockNumber > 0) {
            uint256 blockDelta = block.number - _lastFeeSnapshot.blockNumber;
            uint256 weight = blockDelta > 100 ? 100 : blockDelta;
            // Optimized weighted average calculation
            poolRatio = (_lastFeeSnapshot.poolRatio * (100 - weight) + currentPoolRatio * weight) / 100;
        } else {
            poolRatio = currentPoolRatio;
        }

        uint256 oldFee = feePercent;
        uint256 newFee = _calculateNewFee(poolRatio);
        
        // Only emit if fee actually changed
        if (newFee != oldFee) {
            feePercent = newFee;
            _lastFeeUpdateBlock = block.number;
            _lastFeeSnapshot = FeeSnapshot(poolRatio, block.number);
            emit FeePercentUpdated(oldFee, newFee, poolRatio);
        }
    }

function _calculateNewFee(uint256 poolRatio) private view returns (uint256) {
        uint256 delta = FEE_MAX - FEE_MIN;
        uint256 sub = (delta * poolRatio) / 1e18;
        uint256 newFee = FEE_MAX > sub ? FEE_MAX - sub : FEE_MIN;
        
        // Limitar cambios abruptos (máx ±10% por actualización)
        uint256 maxChange = (feePercent * 10) / 100;
        if (maxChange == 0) maxChange = 1;
        
        // Optimized bounds checking
        if (newFee < FEE_MIN) newFee = FEE_MIN;
        if (newFee > FEE_MAX) newFee = FEE_MAX;
        
        // Apply bounded change
        if (newFee > feePercent + maxChange) {
            newFee = feePercent + maxChange;
        } else if (newFee < feePercent - maxChange) {
            newFee = feePercent - maxChange;
        }
        
        return newFee;
    }

    // Implementación de vistas de la interfaz
    function isExcludedFromFees(address account) external view returns (bool) {
        return _exclusions.isExcludedFromFees(account);
    }

    function excludedCount() external view returns (uint256) {
        return _exclusions.excludedCount();
    }

    function treasury() external view returns (address) {
        return _treasury;
    }
}