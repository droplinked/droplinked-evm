// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./Interfaces/IDroplinkedBase.sol";

contract BenficiaryManager {
    mapping (uint => bool) private _beneficaryExists;
    mapping (uint => Beneficiary) public beneficiaries;

    event BeneficiaryAdded(uint beneficiaryHash, bool isPercentage, uint value, address wallet);

    function getBeneficiaryHash(Beneficiary calldata beneficiary) internal pure returns(uint){
        return uint(keccak256(abi.encode(beneficiary.isPercentage, beneficiary.value, beneficiary._address)));
    }

    function addBeneficiary(Beneficiary calldata beneficary) public returns (uint){
        uint _hash = getBeneficiaryHash(beneficary);
        require(!_beneficaryExists[_hash], "Beneficiary already exists");
        beneficiaries[_hash] = beneficary;
        _beneficaryExists[_hash] = true;
        emit BeneficiaryAdded(_hash, beneficary.isPercentage, beneficary.value, beneficary._address);
        return _hash;
    }

    function getBeneficiary(uint _hash) public view returns(Beneficiary memory){
        require(_beneficaryExists[_hash], "Beneficiary does not exist");
        return beneficiaries[_hash];
    }
}