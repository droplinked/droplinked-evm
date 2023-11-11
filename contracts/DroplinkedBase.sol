//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract DroplinkedBase{
    error AccessDenied();

    struct Request {
        uint tokenId;
        address producer;
        address publisher;
        bool accepted;
    }

    uint public requestCnt;
    address public operatorContract;
    address public owner;

    mapping(uint => Request) public requests;
    mapping(address => mapping(address => mapping(uint => bool)))
        public isRequested;
    mapping(address => mapping(uint => bool)) public publishersRequests;
    mapping(address => mapping(uint => bool)) public producerRequests;
    mapping(uint => mapping(address => uint)) public prices;
    mapping(uint => mapping(address => uint)) public commissions;
    mapping(address => bool) public erc20Addresses;
    
    constructor(){
        owner = msg.sender;
    }
    modifier onlyOwner() {
        if (msg.sender != owner) revert AccessDenied();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operatorContract) revert AccessDenied();
        _;
    }

    function setMetadata(uint price, uint commission, address _owner, uint tokenId) public onlyOperator{
        prices[tokenId][_owner] = price;
        commissions[tokenId][_owner] = commission;
    }

    function setRequest(Request calldata req, uint requestId) public onlyOperator{
        requests[requestId] = req;
    }

    function setAccepted(uint requestId, bool acc) public onlyOperator{
        requests[requestId].accepted = acc;
    }

    function setIsRequested(address producer_account, address publisher_account, uint tokenId, bool value) public onlyOperator{
        isRequested[producer_account][publisher_account][tokenId] = value;
    }

    function setPublishersRequests(address publisher_account, uint requestId, bool value) public onlyOperator{
        publishersRequests[publisher_account][requestId] = value;
    }

    function setProducersRequests(address producer_account, uint requestId, bool value) public onlyOperator{
        producerRequests[producer_account][requestId] = value;
    }

    function setOperator(address _operatorContract) public onlyOwner{
        operatorContract =  _operatorContract;
    }

    function setRequestCnt(uint value) public onlyOperator{
        requestCnt = value;
    }

    function  getRequest(uint req_id) public view onlyOperator returns (Request memory){
        return requests[req_id];
    }

    function  getIsRequested(address producer_account, address publisher_account, uint tokenId) public view onlyOperator returns (bool){
        return isRequested[producer_account][publisher_account][tokenId];
    }

    function  getPublishersRequests(address publisher_account, uint requestId) public view onlyOperator returns (bool){
        return publishersRequests[publisher_account][requestId];
    }

    function  getProducersRequests(address producer_account, uint requestId) public view onlyOperator returns (bool){
        return producerRequests[producer_account][requestId];
    }
    
    function  getRequestCnt() public view onlyOperator returns (uint){
        return requestCnt;
    }

    function addERC20Address(address erc20contract) public onlyOperator{
        erc20Addresses[erc20contract] = true;
    }

    function removeERC20Address(address erc20contract) public onlyOperator{
        erc20Addresses[erc20contract] = false;
    }

    function isERC20AddressIncluded(address erc20contract) public onlyOperator view returns (bool){
        return erc20Addresses[erc20contract];
    }

}