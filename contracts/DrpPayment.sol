// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract DroplinkedPayment{
    function batchPay(address[] memory _recipients, uint256[] memory _amounts) public payable{
        require(_recipients.length == _amounts.length, "Invalid input");
        for(uint256 i = 0; i < _recipients.length; i++){
            payable(_recipients[i]).transfer(_amounts[i]); 
        }
    }
} 