// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Operatable is Ownable {
    error AccessDenied();
    error AddressIsZero();
    address public operatorContract;
    
    function _caller() internal view returns (address) {
        return msg.sender;
    }

    modifier onlyOperator() {
        if (_caller() != operatorContract) revert AccessDenied();
        _;
    }

    function setOperator(address _operatorContract) public onlyOwner{
        if (_operatorContract == address(0)) revert AddressIsZero();
        operatorContract =  _operatorContract;
    }
}