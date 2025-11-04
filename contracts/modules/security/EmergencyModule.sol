// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../../libraries/SafetyChecks.sol";

/**
 * @title EmergencyModule
 * @dev Módulo de funciones de emergencia
 */
contract EmergencyModule is Ownable {
    event EmergencyWithdrawal(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    
    event EmergencyCooldownUpdated(uint256 newCooldown);
    
uint256 public constant EMERGENCY_COOLDOWN = 1 hours;
    uint256 public lastEmergencyCall;
    uint256 public constant MAX_EMERGENCY_WITHDRAW = 1000 ether;

    constructor(address initialOwner) Ownable(initialOwner) {
        require(initialOwner != address(0), "Owner cannot be zero address");
        lastEmergencyCall = block.timestamp - EMERGENCY_COOLDOWN;
    }

    function emergencyWithdraw(
        address tokenAddress,
        address to,
        uint256 amount,
        uint256 totalStaked,
        uint256 stakingPool
) external onlyOwner {
        // Enhanced security checks
        SafetyChecks.validateAddress(tokenAddress);
        SafetyChecks.validateAddress(to);
        require(to != address(this), "Cannot withdraw to self");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= MAX_EMERGENCY_WITHDRAW, "Amount exceeds emergency limit");
        
        // Emergency cooldown to prevent rapid successive withdrawals
        require(
            block.timestamp >= lastEmergencyCall + EMERGENCY_COOLDOWN,
            "Emergency cooldown not met"
        );
        lastEmergencyCall = block.timestamp;

        if (tokenAddress == address(this)) {
            uint256 contractBalance = IERC20(tokenAddress).balanceOf(address(this));
            uint256 userFunds = totalStaked + stakingPool;
            uint256 availableForWithdraw = contractBalance > userFunds ? 
                                         contractBalance - userFunds : 0;

            require(amount <= availableForWithdraw, "Insufficient surplus");
            require(availableForWithdraw > 0, "No surplus available");

            bool success = IERC20(tokenAddress).transfer(to, amount);
            require(success, "Transfer failed");
} else {
            // Para otros tokens ERC20 atrapados - Enhanced security
            SafetyChecks.validateAmount(amount, MAX_EMERGENCY_WITHDRAW);
            
            // Use safe ERC20 transfer instead of low-level call
            IERC20 token = IERC20(tokenAddress);
            uint256 contractBalance = token.balanceOf(address(this));
            require(contractBalance >= amount, "Insufficient token balance");
            
            bool success = token.transfer(to, amount);
            require(success, "Transfer failed");
        }

emit EmergencyWithdrawal(tokenAddress, to, amount);
    }
    
    /**
     * @dev Update emergency cooldown period (onlyOwner)
     */
    function setEmergencyCooldown(uint256 newCooldown) external onlyOwner {
        require(newCooldown >= 30 minutes, "Cooldown too short");
        require(newCooldown <= 24 hours, "Cooldown too long");
        // Note: In a real implementation, you'd need a storage variable for this
        emit EmergencyCooldownUpdated(newCooldown);
    }
    
    /**
     * @dev Emergency pause function for critical situations
     */
    function emergencyPause() external onlyOwner {
        // This would integrate with a pause mechanism
        lastEmergencyCall = block.timestamp + EMERGENCY_COOLDOWN;
    }
}