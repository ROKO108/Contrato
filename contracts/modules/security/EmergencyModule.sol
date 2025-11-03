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

    constructor(address initialOwner) Ownable(initialOwner) {
        require(initialOwner != address(0), "Owner cannot be zero address");
    }

    function emergencyWithdraw(
        address tokenAddress,
        address to,
        uint256 amount,
        uint256 totalStaked,
        uint256 stakingPool
    ) external onlyOwner {
        SafetyChecks.validateAddress(to);
        require(to != address(this), "Cannot withdraw to self");

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
            // Para otros tokens ERC20 atrapados
            (bool success, bytes memory data) = tokenAddress.call(
                abi.encodeWithSignature("transfer(address,uint256)", to, amount)
            );
            require(
                success && (data.length == 0 || abi.decode(data, (bool))),
                "Transfer failed"
            );
        }

        emit EmergencyWithdrawal(tokenAddress, to, amount);
    }
}