// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;
import "./Interfaces/IERC20.sol";
contract myERC20Token is IERC20 {
    function totalSupply() external pure override returns (uint) {
        return 1;
    }
    
    function balanceOf(address account) external view override returns (uint) {}

    function transfer(
        address recipient,
        uint amount
    ) external override returns (bool) {}

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint) {}

    function approve(
        address spender,
        uint amount
    ) external override returns (bool) {}

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external override returns (bool) {}
}