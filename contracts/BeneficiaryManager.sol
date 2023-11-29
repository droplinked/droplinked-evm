// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract BenficiaryManager {
    event BeneficiaryAdded(bytes32 beneficiaryHash, bool isPercentage, uint value, address wallet);
    
    struct Beneficiary{
        bool isPercentage; // if true, the benficiary is like a percentage, if false its value based
        uint value; // if percentage: value / 10000, if value: realvalue00
        address _address; // the wallet address of the benficiary
    }
    
    mapping (uint => bool) private _beneficaryExists;
    mapping (uint => Beneficiary) public beneficiaries;

    function getBeneficiaryHash(Beneficiary calldata beneficiary) public pure returns(uint){
        return uint(keccak256(abi.encode(beneficiary.isPercentage, beneficiary.value, beneficiary._address)));
    }

    function addBeneficiary(Beneficiary calldata beneficary) public returns (uint){
        uint _hash = getBeneficiaryHash(beneficary);
        beneficiaries[_hash] = beneficary;
        _beneficaryExists[_hash] = true;
        return _hash;
    }    

}