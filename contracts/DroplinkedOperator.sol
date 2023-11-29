//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "contracts/IERC20.sol";
import "contracts/IDroplinkedToken.sol";
import "contracts/IDroplinkedBase.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DroplinkedBase.sol";
import "./DroplinkedToken.sol";

contract DroplinkedOperator is Ownable{
    error AccessDenied();
    error AlreadyRequested();
    error RequestNotfound();
    error RequestIsAccepted();
    error NotSupportedERC20Token();
    error DifferentAmounts();
    error TimePassed();
    error oldPrice();
    error NotEnoughTokens(uint tokenId, address tokenOwner);
    error ERC20TransferFailed(uint amount, address receiver);
    event PublishRequest(uint256 tokenId, uint256 requestId);
    event AcceptRequest(uint256 requestId);
    event CancelRequest(uint256 requestId);
    event DisapproveRequest(uint256 requestId);
    event DeployedBase(address _droplinkedBase);
    event DeployedToken(address _droplinkedToken);
    IDroplinkedToken public droplinkedToken;
    IDroplinkedBase public droplinkedBase;
    bool internal locked;
    // Polygon Mumbai: 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada
    // Polygon: 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
    AggregatorV3Interface internal immutable priceFeed =
        AggregatorV3Interface(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0);
    
     // Get the latest price of MATIC/USD with 8 digits shift ( the actual price is 1e-8 times the returned price )
    function getLatestPrice(uint80 roundId) public view returns (uint, uint) {
        (, int256 price, , uint256 timestamp, ) = priceFeed.getRoundData(roundId);
        return (uint(price), timestamp);
    }

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(address _base, address _token) {
        if(_base != address(0)){
            DroplinkedBase base = new DroplinkedBase();
            droplinkedBase = IDroplinkedBase(address(base));
            base.setOperator(address(this));
            emit DeployedBase(address(base));
        } else{
            droplinkedBase = IDroplinkedBase(_base);
        }
        if(_token != address(0)){
            DroplinkedToken token = new DroplinkedToken();
            droplinkedToken = IDroplinkedToken(address(token));
            token.setOperator(address(this));
            emit DeployedToken(address(token));
        } else{
            droplinkedToken = IDroplinkedToken(_token);
        }
    }

    function setHeartBeat(uint16 _heartbeat) public onlyOwner {
        droplinkedToken.setHeartBeat(_heartbeat);
    }

    function setFee(uint256 _fee) public onlyOwner {
        droplinkedToken.setFee(_fee);
    }

    function getFee() public view returns (uint){
        return droplinkedToken.getFee();
    }

    function mint(string calldata _uri, uint256 _price, uint256 _commission, uint256 amount, address receiver) public {
        uint256 tokenId = droplinkedToken.mint(_uri, amount, receiver);
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
        emit PublishRequest(tokenId, requestId);
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
    address signer = 0xE9a42F43bF6EDFB8d9481ec4DcFAADb908370595;

    // Direct Buy
    function purchaseNFT(uint tokenId, address tokenOwner, uint amount, uint80 roundId) public payable{
        (uint ratio, uint timestamp) = getLatestPrice(roundId);
        // check if the tokenOwner has at least amount of the tokenId
        if (droplinkedToken.getOwnerAmount(tokenId, tokenOwner) < amount)
            revert NotEnoughTokens(tokenId, tokenOwner);
        // check the timing
        if (
            block.timestamp > timestamp &&
            block.timestamp - timestamp > 2 * uint(droplinkedToken.getHeartBeat())
        ) revert oldPrice();
        (uint price, ) = droplinkedBase.getMetadata(tokenId, tokenOwner);
        uint product_price = (amount * price * 1e24) / ratio;
        droplinkedToken.safeTransferFrom(tokenOwner, msg.sender, tokenId, amount, "");
        payable(tokenOwner).transfer(product_price);
    }

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
            droplinkedToken.safeTransferFrom(sender, receiver , tokenId, amount, "");
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
            droplinkedToken.safeTransferFrom(sender, receiver , tokenId, amount, "");
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
