// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../access/TokenAccess.sol";
import "../token/TokenSupply.sol";
import "../transfer/TransferProcessor.sol";
import "../transfer/TransferValidation.sol";

/**
 * @title TokenCore - Base functionality for the token
 * @notice Core implementation of the ERC20 standard with basic functionality
 */
abstract contract TokenCore is ERC20, TokenAccess, TokenSupply {
    TransferProcessor private immutable _transferProcessor;
    TransferValidation private immutable _transferValidation;

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner,
        address transferProcessorAddress,
        address transferValidationAddress
    ) ERC20(name, symbol) TokenAccess(initialOwner) {
        _transferProcessor = TransferProcessor(transferProcessorAddress);
        _transferValidation = TransferValidation(transferValidationAddress);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (from != address(0)) { // Skip validation for minting
            require(_transferValidation.validateTransfer(from, to, amount), "TokenCore: transfer validation failed");
            amount = _transferProcessor.processTransfer(from, to, amount);
        } else {
            _checkMintLimits(amount);
            _recordMint(to, amount);
        }
        super._update(from, to, amount);
    }

    function getTransferProcessor() public view returns (address) {
        return address(_transferProcessor);
    }

    function getTransferValidation() public view returns (address) {
        return address(_transferValidation);
    }

    function mint(address to, uint256 amount) external onlyAuthorizedMinter {
        _mint(to, amount);
    }
}
}