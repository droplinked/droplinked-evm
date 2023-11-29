// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Operatable.sol";
import "./IDroplinkedToken.sol";

contract DroplinkedToken is IDroplinkedToken ,ERC1155, Operatable{
    event MintEvent(uint tokenId, address recipient, uint amount, string uri);
    uint public totalSupply;
    uint public fee;
    string public name = "Droplinked";
    string public symbol = "DRP";
    uint16 public heartBeat = 27;
    mapping(uint => string) uris;
    mapping(uint => mapping(address => uint)) private holders;
    uint public tokenCnt;
    mapping(bytes32 => uint) public tokenIdByHash;
    mapping(uint => uint) tokenCnts;
    event HeartBeatUpdated(uint16 newHeartBeat);

    function getOwnerAmount(uint tokenId, address _owner) public view returns (uint){
        return holders[tokenId][_owner];
    }

    function getTokenCnt() public view returns (uint){
        return tokenCnt;
    }

    function getTokenIdByHash(bytes32 metadataHash) public view returns (uint){
        return tokenIdByHash[metadataHash];
    }

    function getTokenAmount(uint tokenId) public view returns (uint){
        return tokenCnts[tokenId];
    }
    
    function getTotalSupply() public view returns (uint){
        return totalSupply;
    }

    function uri(uint tokenId) public view virtual override returns (string memory) {
        return uris[tokenId];
    }
    
    constructor() ERC1155("") {
        fee = 100;
    }

    function setHeartBeat(uint16 _heartbeat) public onlyOperator {
        heartBeat = _heartbeat;
        emit HeartBeatUpdated(_heartbeat);
    }

    function setFee(uint _fee) public onlyOperator {
        fee = _fee;
    }

    function getFee() public view returns (uint){
        return fee;
    }

    function getHeartBeat() public view returns (uint){
        return heartBeat;
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint[] memory ids,
        uint[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
        for (uint i = 0; i < ids.length; ++i) {
            uint id = ids[i];
            uint amount = amounts[i];
            holders[id][from] -= amount;
            holders[id][to] += amount;
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint id,
        uint amount,
        bytes memory data
    ) public virtual override(ERC1155, IDroplinkedToken) {
        if(msg.sender != operatorContract){
            require(
                from == _msgSender() || isApprovedForAll(from, _msgSender()),
                "ERC1155: caller is not token owner or approved"
            );
        }
        _safeTransferFrom(from, to, id, amount, data);
        holders[id][from] -= amount;
        holders[id][to] += amount;
    }

    function mint(
        string calldata _uri,
        uint amount,
        address receiver
    ) public returns (uint){
        bytes32 metadata_hash = keccak256(abi.encode(_uri));
        uint tokenId = tokenIdByHash[metadata_hash];
        if (tokenId == 0) {
            tokenId = tokenCnt + 1;
            tokenCnt++;
            holders[tokenId][receiver] = amount;
            tokenIdByHash[metadata_hash] = tokenId;
        }
        else {
            holders[tokenId][receiver] += amount;
        }
        totalSupply += amount;
        tokenCnts[tokenId] += amount;
        _mint(receiver, tokenId, amount, "");
        if(msg.sender == operatorContract){
            _setApprovalForAll(receiver, operatorContract, true);
        }
        uris[tokenId] = _uri;
        emit URI(_uri, tokenId);
        emit MintEvent(tokenId, tx.origin, amount, _uri);
        return tokenId;
    }
}