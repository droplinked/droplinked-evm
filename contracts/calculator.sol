// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract DroplinkedCalculator{
    function calculate(uint256 price, uint256 ratio) public pure returns(uint256){
        return (1e24 * price) / ratio;
    }
}