// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title MathUtils
 * @dev Librería de utilidades matemáticas extendiendo OpenZeppelin Math
 */
library MathUtils {
    using Math for uint256;

    /**
     * @dev Calcula ratio con precisión específica
     */
    function calculateRatio(
        uint256 numerator,
        uint256 denominator,
        uint256 precision
    ) internal pure returns (uint256) {
        if (denominator == 0) return 0;
        return Math.mulDiv(numerator, precision, denominator);
    }

    /**
     * @dev Aplica límites mín/máx a un valor
     */
    function boundedValue(
        uint256 value,
        uint256 minValue,
        uint256 maxValue
    ) internal pure returns (uint256) {
        if (value < minValue) return minValue;
        if (value > maxValue) return maxValue;
        return value;
    }

    /**
     * @dev Calcula cambio porcentual limitado
     */
    function calculateBoundedChange(
        uint256 currentValue,
        uint256 newValue,
        uint256 maxChangePercent
    ) internal pure returns (uint256) {
        uint256 maxChange = Math.mulDiv(currentValue, maxChangePercent, 100);
        if (maxChange == 0) maxChange = 1;

        if (newValue > currentValue) {
            return Math.min(newValue, currentValue + maxChange);
        } else {
            return Math.max(newValue, currentValue - maxChange);
        }
    }
}