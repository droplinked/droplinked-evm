//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./CouponManager.sol";
import "./Operatable.sol";
import "./BeneficiaryManager.sol";
import "./structs.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DroplinkedBase is CouponManager, Operatable, BenficiaryManager {
    error InvalidSumOfDicount();
    error MetadataNotSet(uint tokenId, address owner);
    error IssuerAlreadySet(uint tokenId, address attemptedIssuer);

    uint private requestCnt;
    
    mapping(uint => Request) private requests;
    mapping(address => mapping(address => mapping(uint => bool))) private isRequested;
    mapping(address => mapping(uint => bool)) private publishersRequests;
    mapping(address => mapping(uint => bool)) private producerRequests;
    // metadatas
    mapping(uint => mapping(address => uint)) private _prices;
    mapping(uint => mapping(address => uint)) private _commissions;
    mapping(uint => ProductType) private _types;
    mapping(uint => mapping(address => uint[])) private _tokenBeneficiaries; // tokenId => (address => List[Beneficiaries])
    
    // issuers, each tokenId specifies a unique asset
    mapping (uint => Issuer) private issuers; // tokenId => issuer

    mapping(address => bool) private erc20addresses;
    mapping(address => address) private paymentWallets;

    function getBeneficariesList(uint tokenId, address _owner) external view returns (uint[] memory){
        return _tokenBeneficiaries[tokenId][_owner];
    }

    function isMetadataSet(uint tokenId, address owner) external view returns (bool){
        // at least it must have a price!
        return (_prices[tokenId][owner] != 0);
    }

    function setMetadata(
        uint price,
        uint commission,
        address _owner,
        uint[] memory _beneficiaries,
        ProductType _type,
        uint tokenId,
        address _paymentWallet
    ) external onlyOperator {
        _prices[tokenId][_owner] = price;
        _commissions[tokenId][_owner] = commission;
        uint percentageSum = 0;
        for (uint i = 0; i < _beneficiaries.length; i++) {
            _tokenBeneficiaries[tokenId][_owner].push(_beneficiaries[i]);
            Beneficiary memory _benef = getBeneficiary(_beneficiaries[i]);
            if(_benef.isPercentage){
                percentageSum += _benef.value;
            }
        }
        if(percentageSum > 1e4) revert InvalidSumOfDicount();
        _types[tokenId] = _type;
        if (paymentWallets[_owner] == address(0))
            paymentWallets[_owner] = _paymentWallet;
    }

    function removeMetadata(uint tokenId, address asker) external onlyOperator {
        delete _prices[tokenId][asker];
        delete _commissions[tokenId][asker];
    }

    function setMetadataAfterPurchase(
        uint price,
        uint commission,
        address _owner,
        uint[] memory _beneficiaries,
        uint tokenId,
        address _paymentWallet
    ) external onlyOperator {
        _prices[tokenId][_owner] = price;
        _commissions[tokenId][_owner] = commission;
        uint percentageSum = 0;
        for (uint i = 0; i < _beneficiaries.length; i++) {
            _tokenBeneficiaries[tokenId][_owner].push(_beneficiaries[i]);
            Beneficiary memory _benef = getBeneficiary(_beneficiaries[i]);
            if(_benef.isPercentage){
                percentageSum += _benef.value;
            }
        }
        if(percentageSum > 1e4) revert InvalidSumOfDicount();
        if (paymentWallets[_owner] == address(0))
            paymentWallets[_owner] = _paymentWallet;
    }

    function setProductType(
        uint tokenId,
        ProductType _type
    ) external onlyOperator {
        _types[tokenId] = _type;    
    }

    function getMetadata(
        uint tokenId,
        address _owner
    ) external view returns (uint, uint, ProductType, address) {
        if (_prices[tokenId][_owner] == 0) revert MetadataNotSet(tokenId, _owner); // if price == 0 then the metadata is not set and product is not available for sale
        return (_prices[tokenId][_owner], _commissions[tokenId][_owner], _types[tokenId], paymentWallets[_owner]);
    }

    function setRequest(
        Request calldata req,
        uint requestId
    ) external onlyOperator {
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
    ) external onlyOperator {
        isRequested[producer_account][publisher_account][tokenId] = value;
    }

    function getIssuer(uint tokenId) public view returns (Issuer memory){
        return issuers[tokenId];
    }

    function setIssuer(
        uint tokenId,
        address issuer,
        uint royalty
    ) external onlyOperator{
        if (getIssuer(tokenId).issuer != address(0))
            revert IssuerAlreadySet(tokenId, issuer);
        Issuer memory _issuer;
        _issuer.issuer = issuer;
        _issuer.royalty = royalty;
        issuers[tokenId] = _issuer;
    }

    function setPublishersRequests(
        address publisher_account,
        uint requestId,
        bool value
    ) external onlyOperator {
        publishersRequests[publisher_account][requestId] = value;
    }

    function setProducersRequests(
        address producer_account,
        uint requestId,
        bool value
    ) external onlyOperator {
        producerRequests[producer_account][requestId] = value;
    }

    function setRequestCnt(uint value) public onlyOperator {
        requestCnt = value;
    }

    function getRequestCnt() external view returns (uint){
        return requestCnt;
    }

    function getRequest(
        uint req_id
    ) external view returns (Request memory) {
        return requests[req_id];
    }

    function getIsRequested(
        address producer_account,
        address publisher_account,
        uint tokenId
    ) external view returns (bool) {
        return isRequested[producer_account][publisher_account][tokenId];
    }

    function getPublishersRequests(
        address publisher_account,
        uint requestId
    ) external view returns (bool) {
        return publishersRequests[publisher_account][requestId];
    }

    function getProducersRequests(
        address producer_account,
        uint requestId
    ) external view returns (bool) {
        return producerRequests[producer_account][requestId];
    }

    function addERC20Address(address erc20contract) external onlyOperator {
        erc20addresses[erc20contract] = true;
    }

    function removeERC20Address(address erc20contract) external onlyOperator {
        erc20addresses[erc20contract] = false;
    }

    function isERC20addressIncluded(
        address erc20contract
    ) external view returns (bool) {
        return erc20addresses[erc20contract];
    }
}