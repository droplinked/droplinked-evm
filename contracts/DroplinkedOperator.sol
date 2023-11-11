//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "contracts/IERC20.sol";
import "contracts/IDroplinkedToken.sol";
import "contracts/IDroplinkedBase.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract DroplinkedOperator {
    error AccessDenied();
    error AlreadyRequested();
    error RequestNotfound();
    error RequestIsAccepted();
    error NotSupportedERC20Token();
    error DifferentAmounts();
    error TimePassed();
    error ERC20TransferFailed(uint amount, address receiver);

    event PulishRequest(uint256 tokenId, uint256 requestId);
    event AcceptRequest(uint256 requestId);
    event CancelRequest(uint256 requestId);
    event DisapproveRequest(uint256 requestId);
    IDroplinkedToken public droplinkedToken;
    IDroplinkedBase public droplinkedBase;
    address public owner;
    bool internal locked;

    modifier onlyOwner() {
        if (msg.sender != owner) revert AccessDenied();
        _;
    }

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(address _baseContract, address _tokenContract) {
        droplinkedToken = IDroplinkedToken(_tokenContract);
        droplinkedBase = IDroplinkedBase(_baseContract);
        owner = msg.sender;
    }

    function setHeartBeat(uint16 _heartbeat) public onlyOwner {
        droplinkedToken.setHeartBeat(_heartbeat);
    }

    function setFee(uint256 _fee) public onlyOwner {
        droplinkedToken.setFee(_fee);
    }

    function mint(string calldata _uri, uint256 _price, uint256 _commission, uint256 amount, address receiver) public {
        uint256 tokenId = droplinkedToken.droplinked_mint(_uri, amount, receiver);
        droplinkedBase.setMetadata(_price, _commission, msg.sender, tokenId);
    }

    function publish_request(address producer_account, uint256 tokenId) public {
        if (droplinkedBase.getIsRequested(producer_account, msg.sender, tokenId)) revert AlreadyRequested();

        uint256 requestId = droplinkedBase.getRequestCnt() + 1;
        droplinkedBase.setRequestCnt(requestId);
        Request memory req;
        req.tokenId = tokenId;
        req.producer = producer_account;
        req.publisher = msg.sender;
        req.accepted = false;
        droplinkedBase.setRequest(req, requestId);
        droplinkedBase.setPublishersRequests(msg.sender, requestId, true);
        droplinkedBase.setProducersRequests(producer_account, requestId, true);
        droplinkedBase.setIsRequested(producer_account,msg.sender,tokenId,true);
        emit PulishRequest(tokenId, requestId);
    }

    function approve_request(uint256 requestId) public {
        if (!droplinkedBase.getProducersRequests(msg.sender, requestId))
            revert RequestNotfound();

        droplinkedBase.setAccepted(requestId, true);
        emit AcceptRequest(requestId);
    }

    function cancel_request(uint256 requestId) public {
        Request memory req = droplinkedBase.getRequest(requestId);
        if (msg.sender != req.publisher) revert AccessDenied();
        if (req.accepted) revert RequestIsAccepted();
        droplinkedBase.setProducersRequests(req.producer, requestId, false);
        droplinkedBase.setPublishersRequests(msg.sender, requestId, false);
        droplinkedBase.setIsRequested(req.producer,msg.sender,req.tokenId,false);
        emit CancelRequest(requestId);
    }

    function disapprove(uint256 requestId) public {
        Request memory req = droplinkedBase.getRequest(requestId);
        if (msg.sender != req.producer) revert AccessDenied();
        droplinkedBase.setProducersRequests(msg.sender, requestId, false);
        droplinkedBase.setPublishersRequests(req.publisher, requestId, false);
        droplinkedBase.setIsRequested(req.producer,req.publisher,req.tokenId,false);
        droplinkedBase.setAccepted(requestId, false);
        emit DisapproveRequest(requestId);
    }

    function addERC20Contract(address erc20token) public onlyOwner{
        droplinkedBase.addERC20Address(erc20token);
    }

    function removeERC20Contract(address erc20token) public onlyOwner{
        droplinkedBase.removeERC20Address(erc20token);
    }
    address signer = 0xe74CFa92DB1c8863c0103CC10cF363008348098c;
    function payment(uint[] memory amounts, address[] memory receivers, uint[] memory tokenIds, uint[] memory tokenAmounts, address tokenReceivers, address[] memory tokenSenders, address erc20TokenContract, uint timestamp, bytes memory signature) public payable noReentrant {
        
        // initial checks
        if (!(amounts.length == receivers.length && tokenIds.length == tokenAmounts.length && tokenAmounts.length == tokenSenders.length)) revert DifferentAmounts();
        // signature & time checks
        if (ECDSA.recover(ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(amounts, receivers, tokenIds, tokenAmounts, tokenReceivers, tokenSenders, erc20TokenContract, timestamp, address(this)))), signature) != signer)
            revert AccessDenied();
        if (
            block.timestamp > timestamp &&
            block.timestamp - timestamp > 2 * droplinkedToken.getHeartBeat()
        ) revert TimePassed();
        // Transfer the NFTS
        for (uint i = 0; i < tokenIds.length; i+=1) {
            uint tokenId = tokenIds[i];
            uint amount = tokenAmounts[i];
            address receiver = tokenReceivers;
            address sender = tokenSenders[i];
            droplinkedToken.DsafeTransferFrom(sender, receiver , tokenId, amount, "");
        }
        if (erc20TokenContract != address(0)){
            // erc20 payment
            if (!droplinkedBase.isERC20AddressIncluded(erc20TokenContract)) revert NotSupportedERC20Token();
            IERC20 erc20 = IERC20(erc20TokenContract);
            for (uint i = 0; i < amounts.length; i++){
                uint amount = amounts[i];
                address receiver = receivers[i];
                if (!erc20.transferFrom(msg.sender, receiver, amount)) revert ERC20TransferFailed(amount, receiver);
            }
        } else {
            // Normal Payment with native token
            for (uint i = 0; i < amounts.length; i++){
                uint amount = amounts[i];
                address receiver = receivers[i];
                payable(receiver).transfer(amount);
            }
        }
    }

    function paymentV2(uint[] memory amounts, address[] memory receivers, uint[] memory tokenIds, uint[] memory tokenAmounts, address[] memory tokenReceivers, address tokenSenders, address erc20TokenContract, uint timestamp, bytes memory signature) public payable noReentrant {
        
        // initial checks
        if (!(amounts.length == receivers.length && tokenIds.length == tokenAmounts.length && tokenAmounts.length == tokenReceivers.length)) revert DifferentAmounts();
        // signature & time checks
        if (ECDSA.recover(ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(amounts, receivers, tokenIds, tokenAmounts, tokenReceivers, tokenSenders, erc20TokenContract, timestamp, address(this)))), signature) != signer)
            revert AccessDenied();
        if (
            block.timestamp > timestamp &&
            block.timestamp - timestamp > 2 * droplinkedToken.getHeartBeat()
        ) revert TimePassed();
        // Transfer the NFTS
        for (uint i = 0; i < tokenIds.length; i+=1) {
            uint tokenId = tokenIds[i];
            uint amount = tokenAmounts[i];
            address receiver = tokenReceivers[i];
            address sender = tokenSenders;
            droplinkedToken.DsafeTransferFrom(sender, receiver , tokenId, amount, "");
        }
        if (erc20TokenContract != address(0)){
            // erc20 payment
            if (!droplinkedBase.isERC20AddressIncluded(erc20TokenContract)) revert NotSupportedERC20Token();
            IERC20 erc20 = IERC20(erc20TokenContract);
            for (uint i = 0; i < amounts.length; i++){
                uint amount = amounts[i];
                address receiver = receivers[i];
                if (!erc20.transferFrom(msg.sender, receiver, amount)) revert ERC20TransferFailed(amount, receiver);
            }
        } else {
            // Normal Payment with native token
            for (uint i = 0; i < amounts.length; i++){
                uint amount = amounts[i];
                address receiver = receivers[i];
                payable(receiver).transfer(amount);
            }
        }
    }
}
