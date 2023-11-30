// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract BenficiaryManager {
    struct Beneficiary{
        bool isPercentage; 
        uint value;
        address _address;
    }
    
    mapping (uint => bool) private _beneficaryExists;
    mapping (uint => Beneficiary) public beneficiaries;

    event BeneficiaryAdded(uint beneficiaryHash, bool isPercentage, uint value, address wallet);
    
    /**
     * @dev Returns the hash of the beneficiary.
     * @param beneficiary The beneficiary details.
     * @return The hash of the beneficiary.
     */
    function getBeneficiaryHash(Beneficiary calldata beneficiary) public pure returns(uint){
        return uint(keccak256(abi.encode(beneficiary.isPercentage, beneficiary.value, beneficiary._address)));
    }

     /**
     * @dev Adds a new beneficiary.
     * @param beneficary The beneficiary details.
     * @return The hash of the beneficiary.
     */
    function addBeneficiary(Beneficiary calldata beneficary) public returns (uint){
        uint _hash = getBeneficiaryHash(beneficary);
        beneficiaries[_hash] = beneficary;
        _beneficaryExists[_hash] = true;
        emit BeneficiaryAdded(_hash, beneficary.isPercentage, beneficary.value, beneficary._address);
        return _hash;
    }

    function getBeneficiary(uint _hash) public view returns(Beneficiary memory){
        return beneficiaries[_hash];
    }
}