// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ITimelock {
    struct TimelockProposal {
        uint256 executeAfter;
        bool executed;
        bytes32 commitHash;
        bool revealed;
        uint256 lastTimelockExecution;
    }

    event TimelockCommitted(bytes32 indexed proposalId, uint256 executeAfter);
    event TimelockRevealed(bytes32 indexed proposalId, bytes32 revealedHash);
    event TimelockQueued(bytes32 indexed proposalId, uint256 executeAfter, bytes32 dataHash);
    event TimelockExecuted(bytes32 indexed proposalId);
    event TimelockCancelled(bytes32 indexed proposalId);

    function commitTreasuryUpdate(bytes32 proposalId, bytes32 commitHash) external;
    function setTreasury(address newTreasury, bytes32 proposalId, bytes32 salt) external;
    function cancelTimelockProposal(bytes32 proposalId) external;
    function timelockProposal(bytes32 proposalId) external view returns (
        uint256 executeAfter,
        bool executed,
        bool revealed,
        bytes32 commitHash,
        uint256 lastExecution
    );
}