//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./CouponManager.sol";
import "./Operatable.sol";
import "./BeneficiaryManager.sol";
import "./IDroplinkedBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DroplinkedBase is CouponManager, Operatable, BenficiaryManager {
    uint public requestCnt;
    error InvalidSumOfDicount();
    mapping(uint => Request) public requests;
    mapping(address => mapping(address => mapping(uint => bool))) public isRequested;
    mapping(address => mapping(uint => bool)) public publishersRequests;
    mapping(address => mapping(uint => bool)) public producerRequests;
    // metadatas
    mapping(uint => mapping(address => uint)) public _prices;
    mapping(uint => mapping(address => uint)) public _commissions;
    mapping(uint => mapping(address => uint[])) public _tokenBeneficiaries; // tokenId => (address => List[Beneficiaries])
    mapping(uint => TokenType) public _tokenTypes; // tokenId => tokenType
    //
    mapping(address => bool) public erc20Addresses;

    function getBeneficariesList(uint tokenId, address _owner) public view returns (uint[] memory){
        return _tokenBeneficiaries[tokenId][_owner];
    }

    // Needs to be updated ----------------
    uint[] private _result;
    function getSelectiveBeneficiaries(uint tokenId, address _owner, uint mode) public returns(uint[] memory){ // 0 : value | 1 : percentage
        delete _result;
        for(uint i = 0; i < _tokenBeneficiaries[tokenId][_owner].length; i++){
            if(!getBeneficiary(_tokenBeneficiaries[tokenId][_owner][i]).isPercentage && mode == 0){
                _result.push(_tokenBeneficiaries[tokenId][_owner][i]);
            }
            if(getBeneficiary(_tokenBeneficiaries[tokenId][_owner][i]).isPercentage && mode == 1){
                _result.push(_tokenBeneficiaries[tokenId][_owner][i]);
            }
        }
        return _result;
    }
    //-----------------------

    function getTokenType(uint tokenId) public view returns (TokenType){
        return _tokenTypes[tokenId];
    }

    function setMetadata(
        uint price,
        uint commission,
        address _owner,
        uint[] memory _beneficiaries,
        TokenType _tokenType,
        uint tokenId
    ) public onlyOperator {
        _tokenTypes[tokenId] = _tokenType;
        _prices[tokenId][_owner] = price;
        _commissions[tokenId][_owner] = commission;
        uint percentageSum = 0;
        for (uint i = 0; i < _beneficiaries.length; i++) {
            _tokenBeneficiaries[tokenId][_owner].push(_beneficiaries[i]);
            Beneficiary memory _benef = getBeneficiary(_beneficiaries[i]);
            if(_benef.isPercentage){
                percentageSum += _benef.value;
            }
            if(percentageSum > 1e4) revert InvalidSumOfDicount();
        }
    }

    function getMetadata(
        uint tokenId,
        address _owner
    ) public view onlyOperator returns (uint, uint) {
        return (_prices[tokenId][_owner], _commissions[tokenId][_owner]);
    }

    function setRequest(
        Request calldata req,
        uint requestId
    ) public onlyOperator {
        requests[requestId] = req;
    }

    function setAccepted(uint requestId, bool acc) public onlyOperator {
        requests[requestId].accepted = acc;
    }

    function setIsRequested(
        address producer_account,
        address publisher_account,
        uint tokenId,
        bool value
    ) public onlyOperator {
        isRequested[producer_account][publisher_account][tokenId] = value;
    }

    function setPublishersRequests(
        address publisher_account,
        uint requestId,
        bool value
    ) public onlyOperator {
        publishersRequests[publisher_account][requestId] = value;
    }

    function setProducersRequests(
        address producer_account,
        uint requestId,
        bool value
    ) public onlyOperator {
        producerRequests[producer_account][requestId] = value;
    }

    function setRequestCnt(uint value) public onlyOperator {
        requestCnt = value;
    }

    function getRequest(
        uint req_id
    ) public view onlyOperator returns (Request memory) {
        return requests[req_id];
    }

    function getIsRequested(
        address producer_account,
        address publisher_account,
        uint tokenId
    ) public view onlyOperator returns (bool) {
        return isRequested[producer_account][publisher_account][tokenId];
    }

    function getPublishersRequests(
        address publisher_account,
        uint requestId
    ) public view onlyOperator returns (bool) {
        return publishersRequests[publisher_account][requestId];
    }

    function getProducersRequests(
        address producer_account,
        uint requestId
    ) public view onlyOperator returns (bool) {
        return producerRequests[producer_account][requestId];
    }

    function getRequestCnt() public view onlyOperator returns (uint) {
        return requestCnt;
    }

    function addERC20Address(address erc20contract) public onlyOperator {
        erc20Addresses[erc20contract] = true;
    }

    function removeERC20Address(address erc20contract) public onlyOperator {
        erc20Addresses[erc20contract] = false;
    }

    function isERC20AddressIncluded(
        address erc20contract
    ) public view onlyOperator returns (bool) {
        return erc20Addresses[erc20contract];
    }
}