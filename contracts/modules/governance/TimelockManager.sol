// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../interfaces/ITimelock.sol";
import "../../libraries/SafetyChecks.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TimelockManager
 * @dev Gestión de timelocks para cambios críticos
 */
contract TimelockManager is ITimelock, Ownable {
    uint256 public constant TIMELOCK_DURATION = 44800; // ~7 días en bloques
    uint256 public constant MIN_TIMELOCK_SPACING = 50000;

    mapping(bytes32 => TimelockProposal) private _timelockQueue;

    constructor(address initialOwner) Ownable(initialOwner) {
        require(initialOwner != address(0), "Owner cannot be zero address");
    }

    function commitTreasuryUpdate(
        bytes32 proposalId,
        bytes32 commitHash
    ) external override onlyOwner {
        require(_timelockQueue[proposalId].executeAfter == 0, "Already committed");
        require(
            block.number >= _timelockQueue[proposalId].lastTimelockExecution + MIN_TIMELOCK_SPACING,
            "Too soon"
        );

        TimelockProposal storage proposal = _timelockQueue[proposalId];
        proposal.executeAfter = block.number + TIMELOCK_DURATION;
        proposal.commitHash = commitHash;

        emit TimelockCommitted(proposalId, proposal.executeAfter);
    }

    function cancelTimelockProposal(bytes32 proposalId) external override onlyOwner {
        require(_timelockQueue[proposalId].executeAfter > 0, "Not found");
        require(!_timelockQueue[proposalId].executed, "Already executed");

        delete _timelockQueue[proposalId];
        emit TimelockCancelled(proposalId);
    }

    function _validateTimelockProposal(
        bytes32 proposalId,
        bytes32 expectedHash,
        bytes32 salt
    ) internal {
        TimelockProposal storage proposal = _timelockQueue[proposalId];
        require(block.number >= proposal.executeAfter, "Too soon");
        require(!proposal.executed, "Already executed");
        require(!proposal.revealed, "Already revealed");

        bytes32 computedHash = keccak256(abi.encodePacked(expectedHash, salt));
        require(proposal.commitHash == computedHash, "Hash mismatch");

        proposal.revealed = true;
        emit TimelockRevealed(proposalId, computedHash);
    }

    function _markProposalExecuted(bytes32 proposalId) internal {
        TimelockProposal storage proposal = _timelockQueue[proposalId];
        proposal.executed = true;
        proposal.lastTimelockExecution = block.number;
        emit TimelockExecuted(proposalId);
    }

    function timelockProposal(bytes32 proposalId) external view override returns (
        uint256 executeAfter,
        bool executed,
        bool revealed,
        bytes32 commitHash,
        uint256 lastExecution
    ) {
        TimelockProposal memory proposal = _timelockQueue[proposalId];
        return (
            proposal.executeAfter,
            proposal.executed,
            proposal.revealed,
            proposal.commitHash,
            proposal.lastTimelockExecution
        );
    }

    // Implementación mínima de setTreasury para cumplir la interfaz.
    function setTreasury(address /* newTreasury */, bytes32 proposalId, bytes32 /* salt */) external override onlyOwner {
        TimelockProposal storage proposal = _timelockQueue[proposalId];
        require(proposal.executeAfter > 0, "Not found");
        require(block.number >= proposal.executeAfter, "Too soon");
        require(!proposal.executed, "Already executed");

        proposal.executed = true;
        proposal.lastTimelockExecution = block.number;
        emit TimelockExecuted(proposalId);
    }

    // Utilidad para generar IDs de propuesta
    function getTimelockProposalId(
        string memory action,
        address param
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(action, param));
    }
}