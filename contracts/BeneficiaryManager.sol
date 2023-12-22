// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./structs.sol";

contract BenficiaryManager {
    mapping (uint => Beneficiary) public beneficiaries;
    event BeneficiaryAdded(uint beneficiaryHash, bool isPercentage, uint value, address wallet);

    function getBeneficiaryHash(Beneficiary calldata beneficiary) internal pure returns(uint){
        return uint(keccak256(abi.encode(beneficiary.isPercentage, beneficiary.value, beneficiary.wallet)));
    }

    function addBeneficiary(Beneficiary calldata beneficary) external returns (uint){
        uint _hash = getBeneficiaryHash(beneficary);
        if (beneficiaries[_hash].wallet != address(0)){
            return _hash;
        }
        beneficiaries[_hash] = beneficary;
        emit BeneficiaryAdded(_hash, beneficary.isPercentage, beneficary.value, beneficary.wallet);
        return _hash;
    }

    function getBeneficiary(uint _hash) public view returns(Beneficiary memory){
        require(beneficiaries[_hash].wallet != address(0), "Beneficiary does not exist");
        return beneficiaries[_hash];
    }
}