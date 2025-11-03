// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/IPauseControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

/**
 * @title PauseModule
 * @dev Módulo de pausa para emergencias que delega al contrato principal
 */
contract PauseModule is IPauseControl, Ownable {
    ERC20Pausable private immutable _token;

    constructor(address initialOwner, address token) Ownable(initialOwner) {
        require(initialOwner != address(0), "Owner cannot be zero address");
        require(token != address(0), "Invalid token address");
        _token = ERC20Pausable(token);
    }

    function pauseWithReason(string memory reason) external override onlyOwner {
        // Delegar la pausa al contrato principal
        (bool success, ) = address(_token).call(abi.encodeWithSignature("pause()"));
        require(success, "Pause failed");
        emit SecurityPause(msg.sender, reason);
    }

    function unpauseWithReason(string memory reason) external override onlyOwner {
        // Delegar el unpause al contrato principal
        (bool success, ) = address(_token).call(abi.encodeWithSignature("unpause()"));
        require(success, "Unpause failed");
        emit SecurityUnpause(msg.sender, reason);
    }

    function isPaused() external view override returns (bool) {
        return _token.paused();
    }
}