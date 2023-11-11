// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DroplinkedToken is ERC1155{
    error AccessDenied();
    error UncontrolledAmount();
    event MintEvent(uint tokenId, address recipient, uint amount);
    event DroplinkedMintEvent(uint tokenId, address recipient, uint amount);
    uint public totalSupply;
    uint public fee;
    address public owner;
    address public operatorContract;
    string public name = "Droplinked";
    string public symbol = "DRP";
    uint16 public heartBeat = 3600;
    mapping(uint => string) uris;
    mapping(uint256 => mapping(address => uint256)) private holders;
    uint public tokenCnt;
    mapping(bytes32 => uint) public tokenIdByHash;
    mapping(uint => uint) tokenCnts;
    event HeartBeatUpdated(uint16 newHeartBeat);

    modifier onlyOwner() {
        if (msg.sender != owner) revert AccessDenied();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operatorContract) revert AccessDenied();
        _;
    }
    

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        return uris[tokenId];
    }

    function setURI(uint tokenId, string calldata _uri) public onlyOperator{
        uris[tokenId] = _uri;
    }
    
    constructor() ERC1155("") {
        fee = 100;
        owner = msg.sender;
    }

    function setOperator(address _operatorContract) public onlyOwner{
        operatorContract =  _operatorContract;
    }

    function setHeartBeat(uint16 _heartbeat) public onlyOperator {
        heartBeat = _heartbeat;
        emit HeartBeatUpdated(_heartbeat);
    }

    function setFee(uint _fee) public onlyOperator {
        fee = _fee;
    }

    function getHeartBeat() public view returns (uint){
        return heartBeat;
    }

    function DsafeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOperator {
        if (amount > holders[id][from]) revert UncontrolledAmount();
        _safeTransferFrom(from, to, id, amount, data);
        holders[id][from] -= amount;
        holders[id][to] += amount;
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            holders[id][from] -= amount;
            holders[id][to] += amount;
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
        holders[id][from] -= amount;
        holders[id][to] += amount;
    }

    function droplinked_mint(
        string calldata _uri,
        uint amount,
        address receiver
    ) public onlyOperator returns (uint){
        bytes32 metadata_hash = keccak256(abi.encode(_uri));
        uint tokenId = tokenIdByHash[metadata_hash];
        if (tokenId == 0) {
            tokenId = tokenCnt + 1;
            tokenCnt++;
            holders[tokenId][receiver] = amount;
            tokenIdByHash[metadata_hash] = tokenId;
        }
        else {
            holders[tokenId][tx.origin] += amount;
        }
        totalSupply += amount;
        tokenCnts[tokenId] += amount;
        _mint(tx.origin, tokenId, amount, "");
        // Approve the operator
        _setApprovalForAll(tx.origin, msg.sender, true);
        uris[tokenId] = _uri;
        emit URI(_uri, tokenId);
        emit MintEvent(tokenId, tx.origin, amount);
        return tokenId;
    }

    function mint(
        string calldata _uri,
        uint amount
    ) public returns (uint){
        bytes32 metadata_hash = keccak256(abi.encode(_uri));
        uint tokenId = tokenIdByHash[metadata_hash];
        if (tokenId == 0) {
            tokenId = tokenCnt + 1;
            tokenCnt++;
            holders[tokenId][msg.sender] = amount;
            tokenIdByHash[metadata_hash] = tokenId;
        }
        else {
            holders[tokenId][msg.sender] += amount;
        }
        totalSupply += amount;
        tokenCnts[tokenId] += amount;
        _mint(msg.sender, tokenId, amount, "");
        uris[tokenId] = _uri;
        emit URI(_uri, tokenId);
        emit DroplinkedMintEvent(tokenId, msg.sender, amount);
        return tokenId;
    }
}