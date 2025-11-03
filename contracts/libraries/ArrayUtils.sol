// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ArrayUtils
 * @dev Librería de utilidades para manejo de arrays
 */
library ArrayUtils {
    /**
     * @dev Remueve un elemento de un array reemplazándolo con el último
     */
    function removeAndReplaceWithLast(
        address[] storage array,
        address element
    ) internal returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                if (i != array.length - 1) {
                    array[i] = array[array.length - 1];
                }
                array.pop();
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Verifica si un elemento existe en el array
     */
    function contains(
        address[] storage array,
        address element
    ) internal view returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return true;
            }
        }
        return false;
    }
}