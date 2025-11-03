// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IFeeProcessor {
    struct FeeSnapshot {
        uint256 poolRatio;
        uint256 blockNumber;
    }

    event FeeApplied(
        address indexed from,
        uint256 totalFee,
        uint256 burnAmount,
        uint256 stakingAmount,
        uint256 treasuryAmount
    );
    event FeePercentUpdated(uint256 oldFee, uint256 newFee, uint256 poolRatio);
    event FeeRangeUpdated(uint256 minFee, uint256 maxFee, uint256 timestamp);
    event FeeExclusionSet(address indexed account, bool excluded);

    function feePercent() external view returns (uint256);
    function isExcludedFromFees(address account) external view returns (bool);
    function excludedCount() external view returns (uint256);
    function setExcludedFromFees(address account, bool excluded) external;
    function setFeeRange(uint256 minFee, uint256 maxFee, bytes32 proposalId, bytes32 salt) external;
}