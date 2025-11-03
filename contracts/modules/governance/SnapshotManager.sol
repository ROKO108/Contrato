// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../libraries/ArrayUtils.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface ISnapshotToken {
    function snapshot() external returns (uint256);
    function totalSupply() external view returns (uint256);
}

/**
 * @title SnapshotManager
 * @dev Gestión de snapshots para gobernanza
 */
contract SnapshotManager {
    using Counters for Counters.Counter;

    struct SnapshotData {
        uint256 id;
        uint256 blockNumber;
        uint256 timestamp;
        mapping(address => uint256) balances;
        uint256 totalSupply;
        bytes32 proposalId;
    }

    event StateSnapshotTaken(bytes32 indexed proposalId, uint256 blockNumber);

    Counters.Counter private _snapshotCounter;
    mapping(bytes32 => SnapshotData) private _snapshots;
    mapping(uint256 => bytes32) private _snapshotIds;

    ISnapshotToken private immutable _token;

    constructor(address token_) {
        require(token_ != address(0), "Invalid token");
        _token = ISnapshotToken(token_);
    }

    function takeSnapshot(bytes32 proposalId) external returns (uint256) {
        _snapshotCounter.increment();
        uint256 snapshotId = _snapshotCounter.current();

        SnapshotData storage snap = _snapshots[proposalId];
        snap.id = snapshotId;
        snap.blockNumber = block.number;
        snap.timestamp = block.timestamp;
        snap.totalSupply = _token.totalSupply();
        snap.proposalId = proposalId;

        _snapshotIds[snapshotId] = proposalId;

        emit StateSnapshotTaken(proposalId, block.number);
        
        return snapshotId;
    }

    function getSnapshotData(uint256 snapshotId) external view returns (
        uint256 id,
        uint256 blockNumber,
        uint256 timestamp,
        uint256 totalSupply,
        bytes32 proposalId
    ) {
        bytes32 pid = _snapshotIds[snapshotId];
        SnapshotData storage snap = _snapshots[pid];
        
        return (
            snap.id,
            snap.blockNumber,
            snap.timestamp,
            snap.totalSupply,
            snap.proposalId
        );
    }

    function getBalanceAtSnapshot(
        uint256 snapshotId,
        address account
    ) external view returns (uint256) {
        bytes32 pid = _snapshotIds[snapshotId];
        return _snapshots[pid].balances[account];
    }
}