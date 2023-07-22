// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IPaymentContract{
    function batchPay(address[] memory _recipients, uint256[] memory _amounts) external payable;
}

contract Droplinked is ERC1155 {

    IPaymentContract internal immutable paymentContract;
    // Using price feed of chainlink to get the price of MATIC/USD without external source or centralization
    // Binance : 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
    // Polygon : 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada
    AggregatorV3Interface internal immutable priceFeed = AggregatorV3Interface(0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);

    // The heartbeat is the time that the pricefeed is updated(2 minutes)
    uint16 public heartBeat = 120;

    error oldPrice();

    // This error will be used when transfering money to an account fails
    error WeiTransferFailed(string message);

    // NotEnoughBalance indicates the msg.value is less than expected
    error NotEnoughBalance();

    // NotEnoughtTokens indicates the amount of tokens you want to purchase is more than actual existing
    error NotEnoughtTokens();

    // AccessDenied indicates you want to do a operation (CancelRequest or Accept) that you are not allowed to do
    error AccessDenied();

    // AlreadyRequested indicates that you have already requested for the tokenId you are trying to request to again
    error AlreadyRequested();

    // RequestNotfound is thrown when the caller is not the person that is needed to accept the request
    error RequestNotfound();

    // RequestIsAccepted is thrown when the publisher tries to cancel its request but the request is accepted beforehand
    error RequestIsAccepted();

    // The Mint would be emitted on Minting new product
    event Mint_event(uint tokenId, address recipient, uint amount);

    // PublishRequest would be emitted when a new publish request is made
    event PulishRequest(uint tokenId, uint requestId);

    // AcceptRequest would be emitted when the `approve_request` function is called
    event AcceptRequest(uint requestId);

    // Cancelequest would be emitted when the `cancel_request` function is called
    event CancelRequest(uint requestId);

    // DisapproveRequest would be emitted when the `disapprove` function is called
    event DisapproveRequest(uint requestId);

    // DirectBuy would be emitted when the `direct_buy` function is called and the transfer is successful
    event DirectBuy(uint price, address from, address to);

    // RecordedBuy would be emitted when the `buy_recorded` function is called and the transfers are successful
    event RecordedBuy(
        address producer,
        uint tokenId,
        uint shipping,
        uint tax,
        uint amount,
        address buyer
    );

    // AffiliateBuy would be emitted when the `buy_affiliate` function is called and the transfers are successful
    event AffiliateBuy(
        uint requestId,
        uint amount,
        uint shipping,
        uint tax,
        address buyer
    );

    event HeartBeatUpdated(uint16 newHeartBeat);

    event FeeUpdated(uint newFee);

    // NFTMetadata Struct
    struct NFTMetadata {
        string ipfsUrl;
        uint price;
        uint comission;
    }

    // Request struct
    struct Request {
        uint tokenId;
        address producer;
        address publisher;
        bool accepted;
    }

    // TokenID => ItsTotalSupply
    mapping(uint => uint) tokenCnts;

    // Keeps the record of the minted tokens
    uint public tokenCnt;

    // Keeps the record of the requests made
    uint public requestCnt;

    // Keeps record of the totalSupply of the contract
    uint public totalSupply;

    // The ratio Verifier for payment methods
    address public immutable owner;

    // The fee (*100) for Droplinked Account (ratioVerifier)
    uint public fee;

    // TokenID => metadata
    mapping(uint => NFTMetadata) public metadatas;

    // RequestID => Request
    mapping(uint => Request) public requests;

    // ProducerAddress => ( TokenID => isRequested )
    mapping(address => mapping(uint => bool)) public isRequested;

    // HashOfMetadata => TokenID
    mapping(bytes32 => uint) public tokenIdByHash;

    // PublisherAddress => ( RequestID => boolean )
    mapping(address => mapping(uint => bool)) public publishersRequests;

    // ProducerAddress => ( RequestID => boolean )
    mapping(address => mapping(uint => bool)) public producerRequests;

    // TokenID => string URI
    mapping(uint => string) uris;

    mapping(uint256 => mapping(address => uint256)) private holders;

    modifier onlyOwner() {
        if (msg.sender != owner) revert AccessDenied();
        _;
    }

    constructor(address _paymentContract) ERC1155("") {
        fee = 100;
        owner = msg.sender;
        paymentContract = IPaymentContract(_paymentContract);
    }

    function setHeartBeat(uint16 _heartbeat) public onlyOwner {
        heartBeat = _heartbeat;
        emit HeartBeatUpdated(_heartbeat);
    }

    function setFee(uint _fee) public onlyOwner {
        fee = _fee;
        emit FeeUpdated(_fee);
    }

    // Get the latest price of MATIC/USD with 8 digits shift ( the actual price is 1e-8 times the returned price )
    function getLatestPrice(uint80 roundId) public view returns (uint, uint) {
        (, int256 price, , uint256 timestamp, ) = priceFeed.getRoundData(
            roundId
        );
        return (uint(price), timestamp);
    }

    function uri(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        return uris[tokenId];
    }

    function mint(
        string calldata _uri,
        uint _price,
        uint _comission,
        uint amount
    ) public {
        // Calculate the metadataHash using its IPFS uri, price, and comission
        bytes32 metadata_hash = keccak256(abi.encode(_uri, _price, _comission));
        // Get the TokenID from `tokenIdByHash` by its calculated hash
        uint tokenId = tokenIdByHash[metadata_hash];
        // If NOT FOUND
        if (tokenId == 0) {
            // Create a new tokenID
            tokenId = tokenCnt + 1;
            tokenCnt++;
            metadatas[tokenId].ipfsUrl = _uri;
            metadatas[tokenId].price = _price;
            metadatas[tokenId].comission = _comission;
            holders[tokenId][msg.sender] = amount;
            tokenIdByHash[metadata_hash] = tokenId;
        }
        // If FOUND
        else {
            // Update the old tokenIds amount
            holders[tokenId][msg.sender] += amount;
        }
        totalSupply += amount;
        tokenCnts[tokenId] += amount;
        _mint(msg.sender, tokenId, amount, "");
        uris[tokenId] = _uri;
        emit URI(_uri, tokenId);
        emit Mint_event(tokenId, msg.sender, amount);
    }

    function publish_request(address producer_account, uint tokenId) public {
        if (isRequested[producer_account][tokenId]) revert AlreadyRequested();
        // Create a new requestId
        uint requestId = requestCnt + 1;
        // Update the requests_cnt
        requestCnt++;
        // Create the request and add it to producer's incoming reqs, and publishers outgoing reqs
        requests[requestId].tokenId = tokenId;
        requests[requestId].producer = producer_account;
        requests[requestId].publisher = msg.sender;
        requests[requestId].accepted = false;
        publishersRequests[msg.sender][requestId] = true;
        producerRequests[producer_account][requestId] = true;
        isRequested[producer_account][tokenId] = true;
        emit PulishRequest(tokenId, requestId);
    }

    // The overloading of the safeBatchTransferFrom from ERC1155 to update contract variables
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

    // ERC1155 overloading to update the contracts state when the safeTrasnferFrom is called
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

    function approve_request(uint requestId) public {
        if (!producerRequests[msg.sender][requestId]) revert RequestNotfound();
        requests[requestId].accepted = true;
        emit AcceptRequest(requestId);
    }

    function cancel_request(uint requestId) public {
        if (msg.sender != requests[requestId].publisher) revert AccessDenied();
        if (requests[requestId].accepted) revert RequestIsAccepted();
        // remove the request from producer's incoming requests, and from publisher's outgoing requests
        producerRequests[requests[requestId].producer][requestId] = false;
        publishersRequests[msg.sender][requestId] = false;
        // Also set the isRequested to false since we deleted the request
        isRequested[requests[requestId].producer][
            requests[requestId].tokenId
        ] = false;
        emit CancelRequest(requestId);
    }

    function disapprove(uint requestId) public {
        if (msg.sender != requests[requestId].producer) revert AccessDenied();
        // remove the request from producer's incoming requests, and from publisher's outgoing requests
        producerRequests[msg.sender][requestId] = false;
        publishersRequests[requests[requestId].publisher][requestId] = false;
        // Also set the isRequested to false since we deleted the request
        isRequested[requests[requestId].producer][
            requests[requestId].tokenId
        ] = false;
        // And set the `accepted` property of the request to false
        requests[requestId].accepted = false;
        emit DisapproveRequest(requestId);
    }

    function direct_buy(
        uint price,
        address recipient,
        uint80 roundId
    ) public payable {
        // Get timestamp from roundId and check if its less than 2 heartbeats passed
        // Calculations
        (uint ratio, uint timestamp) = getLatestPrice(roundId);
        // check the timestamp
        if (
            block.timestamp > timestamp &&
            block.timestamp - timestamp > 2 * heartBeat
        ) revert oldPrice();
        uint totalAmount = (price * 1e24) / ratio;
        uint droplinkedShare = (totalAmount * fee) / 1e4;
        // check if the sended amount is more than the needed
        if (msg.value < totalAmount) revert NotEnoughBalance();
        emit DirectBuy(price, msg.sender, recipient);
        // Transfer money & checks

        address[] memory recivers = new address[](2);
        recivers[0] = owner;
        recivers[1] = recipient;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = droplinkedShare;
        amounts[1] = totalAmount - droplinkedShare;
        paymentContract.batchPay{value: msg.value}(
            recivers,
            amounts
        );
    }

    function buy_recorded(
        address producer,
        uint tokenId,
        uint shipping,
        uint tax,
        uint amount,
        uint80 roundId
    ) public payable {
        if (holders[tokenId][producer] < amount) revert NotEnoughtTokens();
        // Calculations
        (uint ratio, uint timestamp) = getLatestPrice(roundId);
        // check the timestamp
        if (
            block.timestamp > timestamp &&
            block.timestamp - timestamp > 2 * heartBeat
        ) revert oldPrice();
        uint product_price = (amount * metadatas[tokenId].price * 1e24) / ratio;
        uint totalPrice = product_price + (((shipping + tax) * 1e24) / ratio);
        if (msg.value < totalPrice) revert NotEnoughBalance();
        uint droplinked_share = (product_price * fee) / 1e4;
        uint producer_share = totalPrice - droplinked_share;
        // Transfer the product on the contract state
        holders[tokenId][msg.sender] += amount;
        holders[tokenId][producer] -= amount;
        emit RecordedBuy(producer, tokenId, shipping, tax, amount, msg.sender);
        // Actual money transfers & checks
        address[] memory recivers = new address[](2);
        recivers[0] = owner;
        recivers[1] = producer;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = droplinked_share;
        amounts[1] = producer_share;
        paymentContract.batchPay{value: msg.value}(
            recivers,
            amounts
        );
    }

    function buy_affiliate(
        uint requestId,
        uint amount,
        uint shipping,
        uint tax,
        uint80 roundId
    ) public payable {
        // checks and calculations
        address prod = requests[requestId].producer;
        address publ = requests[requestId].publisher;
        uint tokenId = requests[requestId].tokenId;
        (uint ratio, uint timestamp) = getLatestPrice(roundId);
        // check the timestamp
        if (
            block.timestamp > timestamp &&
            block.timestamp - timestamp > 2 * heartBeat
        ) revert oldPrice();
        uint product_price = (amount * metadatas[tokenId].price * 1e24) / ratio;
        uint total_amount = product_price + (((shipping + tax) * 1e24) / ratio);
        if (msg.value < total_amount) revert NotEnoughBalance();

        if (holders[tokenId][prod] < amount) revert NotEnoughtTokens();
        uint droplinked_share = (product_price * fee) / 1e4;
        uint publisher_share = ((product_price - droplinked_share) *
            metadatas[tokenId].comission) / 1e4;
        uint producer_share = total_amount -
            (droplinked_share + publisher_share);
        // Transfer on contract
        holders[tokenId][msg.sender] += amount;
        holders[tokenId][prod] -= amount;
        emit AffiliateBuy(requestId, amount, shipping, tax, msg.sender);
        // Money transfer
        address[] memory recivers = new address[](3);
        recivers[0] = owner;
        recivers[1] = prod;
        recivers[2] = publ;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = droplinked_share;
        amounts[1] = producer_share;
        amounts[2] = publisher_share;
        paymentContract.batchPay{value: msg.value}(
            recivers,
            amounts
        );
    }

    // Returns the totalSupply of the contract
    function totalSupplyOf(uint256 id) public view returns (uint256) {
        return tokenCnts[id];
    }

    // Returns the balance of the address for the tokenId
    function balanceOf(
        address account,
        uint256 id
    ) public view override returns (uint256) {
        return holders[id][account];
    }
}
