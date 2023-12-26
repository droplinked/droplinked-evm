// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;

contract chainLink{
    function getRoundData(
        uint roundId
    ) external view returns (uint, int256, uint, uint256, uint) {
        return (1e6, 1e6, 1e6, block.timestamp, 1);
    }
}