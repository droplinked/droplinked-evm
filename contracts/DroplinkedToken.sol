// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Operatable.sol";

contract DroplinkedToken is ERC1155, Operatable{
    event MintEvent(uint tokenId, address recipient, uint amount, string uri);
    event HeartBeatUpdated(uint256 newHeartBeat);
    event ManageWalletUpdated(address newManagedWallet);
    event FeeUpdated(uint newFee);

    uint public totalSupply;
    uint public fee;
    string public name = "Droplinked";
    string public symbol = "DROP";
    uint256 public heartBeat = 1200;
    uint public tokenCnt;
    address public managedWallet = 0x8c906310C5F64fe338e27Bd9fEf845B286d0fc1e;
    mapping(uint => string) uris;
    mapping(bytes32 => uint) public tokenIdByHash;
    mapping(uint => uint) tokenCnts;

    constructor() ERC1155("") {
        fee = 100;
    }

    function getOwnerAmount(uint tokenId, address _owner) external view returns (uint){
        return balanceOf(_owner, tokenId);
    }

    function getTokenCnt() external view returns (uint){
        return tokenCnt;
    }

    function getTokenIdByHash(bytes32 metadataHash) external view returns (uint){
        return tokenIdByHash[metadataHash];
    }

    function getTokenAmount(uint tokenId) external view returns (uint){
        return tokenCnts[tokenId];
    }
    
    function getTotalSupply() external view returns (uint){
        return totalSupply;
    }

    function uri(uint tokenId) public view virtual override returns (string memory) {
        return uris[tokenId];
    }
    
    function getManagedWallet() external view returns (address){
        return managedWallet;
    }

    function setManagedWallet(address _newManagedWallet) external onlyOwner {
        managedWallet = _newManagedWallet;
        emit ManageWalletUpdated(_newManagedWallet);
    }

    function setHeartBeat(uint256 _heartbeat) external onlyOperator {
        heartBeat = _heartbeat;
        emit HeartBeatUpdated(_heartbeat);
    }

    function setFee(uint _fee) external onlyOperator {
        fee = _fee;
        emit FeeUpdated(_fee);
    }

    function getFee() external view returns (uint){
        return fee;
    }

    function getHeartBeat() external view returns (uint256){
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
    }



    function safeTransferFrom(
        address from,
        address to,
        uint id,
        uint amount,
        bytes memory data
    ) public virtual override {
        if(msg.sender != operatorContract){
            require(
                from == _msgSender() || isApprovedForAll(from, _msgSender()),
                "ERC1155: caller is not token owner or approved"
            );
        }
        _safeTransferFrom(from, to, id, amount, data);
    }

    function mint(
        string calldata _uri,
        uint amount,
        address receiver,
        bool accepted
    ) external onlyOperator returns (uint){ 
        bytes32 metadata_hash = keccak256(abi.encode(_uri));
        uint tokenId = tokenIdByHash[metadata_hash];
        if (tokenId == 0) {
            tokenId = tokenCnt + 1;
            tokenCnt++;
            tokenIdByHash[metadata_hash] = tokenId;
        }
        totalSupply += amount;
        tokenCnts[tokenId] += amount;
        _mint(receiver, tokenId, amount, "");
        if(msg.sender == operatorContract){
            _setApprovalForAll(receiver, operatorContract, true);
            if (accepted) _setApprovalForAll(receiver, managedWallet, true);
        }
        uris[tokenId] = _uri;
        emit URI(_uri, tokenId);
        emit MintEvent(tokenId, tx.origin, amount, _uri);
        return tokenId;
    }
    function droplinkedSafeBatchTransferFrom(address from, address[] memory to, uint[] memory ids, uint[] memory amounts) external {
        for (uint i = 0; i < to.length; i++) {
            safeTransferFrom(from, to[i], ids[i], amounts[i], "");
        }
    }
}