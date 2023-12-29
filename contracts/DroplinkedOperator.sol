//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "./Interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DroplinkedToken.sol";
import "./DroplinkedBase.sol";
import "./CouponManager.sol";

import "hardhat/console.sol";
import "./test/chainLink.sol";

//TODO: Custom error catcher in ethersjs
//TODO: remove product from sale and vice versa -> remove metadata

contract DroplinkedOperator is Ownable, ReentrancyGuard {
    error AccessDenied();
    error CannotChangeMetata();
    error InvalidFee(uint fee);
    error AlreadyRequested();
    error RequestNotfound();
    error RequestIsAccepted();
    error RequestIsNotAccepted();
    error InvalidCouponProducer();
    error NotSupportedERC20Token();
    error oldPrice();
    error AffiliatePOD();
    error DifferentLength();
    error InvalidCouponValue();
    error CouponCantBeApplied();
    error NotEnoughTokens(uint tokenId, address tokenOwner);
    error ERC20TransferFailed(uint amount, address receiver);
    error ZeroPrice();
    error InvalidFromAddress();
    error MinterIsNotIssuer();

    event PublishRequest(uint256 tokenId, uint256 requestId);
    event AcceptRequest(uint256 requestId);
    event CancelRequest(uint256 requestId);
    event DisapproveRequest(uint256 requestId);
    event DeployedBase(address _droplinkedBase);
    event DeployedToken(address _droplinkedToken);
    event Purchase(string memo);
    event ERC20PaymentAdded(address tokenAddress);
    event ERC20PaymentRemoved(address removedToken);

    DroplinkedToken public droplinkedToken;
    DroplinkedBase public droplinkedBase;
    bool internal locked;

    // Polygon Mumbai: 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada
    // Polygon: 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
    //AggregatorV3Interface internal immuteable priceFeed = AggregatorV3Interface(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0);
    chainLink priceFeed = new chainLink();
    address public immutable droplinkedWallet = 0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78;
    
    // Get the latest price of MATIC/USD with 8 digits shift ( the actual price is 1e-8 times the returned price )
    function getLatestPrice(uint80 roundId) internal view returns (uint, uint) {
        (, int256 price, , uint256 timestamp, ) = priceFeed.getRoundData(
            roundId
        );
        return (uint(price), timestamp);
    }

    constructor(address _base, address _token) {
        if (_base == address(0)) {
            DroplinkedBase base = new DroplinkedBase();
            droplinkedBase = DroplinkedBase(address(base));
            base.setOperator(address(this));
            emit DeployedBase(address(base));
        } else {
            droplinkedBase = DroplinkedBase(_base);
        }
        if (_token == address(0)) {
            DroplinkedToken token = new DroplinkedToken();
            droplinkedToken = DroplinkedToken(address(token));
            token.setOperator(address(this));
            emit DeployedToken(address(token));
        } else {
            droplinkedToken = DroplinkedToken(_token);
        }
    }

    function setHeartBeat(uint16 _heartbeat) public onlyOwner {
        droplinkedToken.setHeartBeat(_heartbeat);
    }

    function setFee(uint256 _fee) public onlyOwner {
        if (_fee > 1e4) revert InvalidFee(_fee);
        droplinkedToken.setFee(_fee);
    }

    function getFee() public view returns (uint) {
        return droplinkedToken.getFee();
    }

    function mint(
        string calldata _uri,
        uint256 _price,
        uint256 _commission,
        uint256 amount,
        address receiver,
        ProductType _type,
        address _paymentWallet,
        Beneficiary[] memory _beneficiaries,
        bool acceptedManageWallet,
        uint royalty
    ) public {
        if (_price == 0) revert ZeroPrice();
        uint256 tokenId = droplinkedToken.mint(_uri, amount, receiver, acceptedManageWallet);
        if (!droplinkedBase.isMetadataSet(tokenId,msg.sender)){
            setMetadata(
                _price,
                _commission,
                _beneficiaries,
                _type,
                tokenId,
                _paymentWallet);
        }
        if (droplinkedBase.getIssuer(tokenId).issuer == address(0)) // not reverting if != because people may want to mint more
            droplinkedBase.setIssuer(tokenId, msg.sender, royalty);
        else if (droplinkedBase.getIssuer(tokenId).issuer != msg.sender)
            revert MinterIsNotIssuer();
    }

    function publish_request(address producer_account, uint256 tokenId) public {
        if (
            droplinkedBase.getIsRequested(producer_account, msg.sender, tokenId)
        ) revert AlreadyRequested();

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
        droplinkedBase.setIsRequested(
            producer_account,
            msg.sender,
            tokenId,
            true
        );
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
        droplinkedBase.setIsRequested(
            req.producer,
            msg.sender,
            req.tokenId,
            false
        );
        emit CancelRequest(requestId);
    }

    function disapprove(uint256 requestId) public {
        Request memory req = droplinkedBase.getRequest(requestId);
        if (msg.sender != req.producer) revert AccessDenied();
        droplinkedBase.setProducersRequests(msg.sender, requestId, false);
        droplinkedBase.setPublishersRequests(req.publisher, requestId, false);
        droplinkedBase.setIsRequested(
            req.producer,
            req.publisher,
            req.tokenId,
            false
        );
        droplinkedBase.setAccepted(requestId, false);
        emit DisapproveRequest(requestId);
    }

    function addERC20Contract(address erc20token) public onlyOwner {
        require(IERC20(erc20token).totalSupply() > 0, "Not a valid ERC20 contract");
        droplinkedBase.addERC20Address(erc20token);
        emit ERC20PaymentAdded(erc20token);
    }

    function removeERC20Contract(address erc20token) public onlyOwner {
        droplinkedBase.removeERC20Address(erc20token);
        emit ERC20PaymentRemoved(erc20token);
    }

    function toETHPrice(uint value, uint ratio) private pure returns (uint) {
        return (1e22 * value) / ratio;
    }

    function applyPercentage(
        uint value,
        uint percentage
    ) private pure returns (uint) {
        return (value * percentage) / 1e4;
    }

    function _applyCoupon(
        uint totalProductPrice,
        bool isPercentage,
        uint couponValue,
        uint ratio
    ) private pure returns (uint) {
        uint newProductPrice = 0;
        if (!isPercentage) {
            uint _creditValue = toETHPrice(couponValue, ratio);
            if (_creditValue > totalProductPrice) {
                newProductPrice = 0;
                _creditValue -= totalProductPrice;
            } else {
                newProductPrice = totalProductPrice - _creditValue;
                _creditValue = 0;
            }
        } else {
            if (couponValue > 1e4) revert InvalidCouponValue();
            newProductPrice = applyPercentage(totalProductPrice, 1e4 - couponValue); // for example 10% would lead to 90% of the original price
        }
        return newProductPrice;
    }

    function transferTBDValues(uint[] memory tbdValues, address[] memory tbdReceivers, uint ratio) private returns(uint){
        uint currentValue = 0;
        // transfer the tbdValues to tbdReceivers
        // console.log("transfering funds %s", tbdReceivers.length);
        for (uint i = 0; i < tbdReceivers.length; i++) {
            // console.log("transfering %s to %s", toETHPrice(tbdValues[i], ratio), tbdReceivers[i]);
            uint value = toETHPrice(tbdValues[i], ratio);
            currentValue += value;
            payable(tbdReceivers[i]).transfer(value);
        }
        return currentValue;
    }

    function droplinkedPurchase(address _shop, uint80 chainLinkRoundId, uint totalTaxAndShipping, uint[] memory tbdValues, address[] memory tbdReceivers, PurchaseData[] memory cartItems, CouponProof memory proof, string memory memo) public payable nonReentrant{
        // initial checks
        if (tbdReceivers.length != tbdValues.length) revert DifferentLength();
        (uint ratio, uint timestamp) = getLatestPrice(chainLinkRoundId);
        // TODO: uncomment this
        // if (block.timestamp > timestamp && block.timestamp - timestamp > 2 * uint(droplinkedToken.getHeartBeat())) revert oldPrice();
        if (ratio == 0) revert ("Chainlink Contract not found");
        uint tbdTransferedValue = transferTBDValues(tbdValues, tbdReceivers, ratio);
        uint totalProductsPrice = msg.value - toETHPrice(totalTaxAndShipping, ratio) - tbdTransferedValue;
        uint newProductsPrice = totalProductsPrice;
        uint creditValue = 0;
        uint fee = droplinkedToken.getFee();
        // check the coupon
        if (proof.provided){
            Coupon memory coupon = droplinkedBase.checkAndGetCoupon(proof);
            if (coupon.couponProducer != _shop) revert InvalidCouponProducer();
            newProductsPrice = _applyCoupon(totalProductsPrice, coupon.isPercentage, coupon.value, ratio);
            creditValue = coupon.value;
        }        
        // console.log("Checking for cart items");
        // console.log("contract: %s", address(this).balance);

        // iterate over items in cart
        for (uint i = 0; i < cartItems.length; i++){
            PurchaseData memory item = cartItems[i];
            // console.log("Cart Item %s", i);
            // console.log("\t ID: %s", item.id);
            // console.log("\t Amount: %s", item.amount);
            // console.log("\t Is Affiliate: %s", item.isAffiliate);
            uint _productETHPrice = 0;
            address _publisher = address(0);
            address _producer;
            uint tokenId = 0;
            uint __producerShare = 0;
            if (item.isAffiliate){
                Request memory request = droplinkedBase.getRequest(item.id);
                if(!request.accepted) revert RequestIsNotAccepted();
                _publisher = request.publisher;
                if(creditValue != 0) revert CouponCantBeApplied();
                if (_publisher != _shop) revert InvalidFromAddress();
                _producer = request.producer;
                tokenId = request.tokenId;
            } else {
                _producer = _shop;
                tokenId = item.id;
            }
            // console.log("1");
            (uint _productPrice, uint _commission, ProductType _type, address _paymentWallet) = droplinkedBase.getMetadata(tokenId, _producer); // <-- would fail if the metadata is not found for that product (not set)
            if (_type == ProductType.POD && _publisher != address(0)) revert AffiliatePOD();
            _productETHPrice = (toETHPrice(_productPrice * item.amount, ratio) * newProductsPrice) / totalProductsPrice;
            Issuer memory issuer = droplinkedBase.getIssuer(tokenId);
            uint __royaltyShare = applyPercentage(_productETHPrice, issuer.royalty);
            __producerShare = _productETHPrice;
            uint __publisherShare = _publisher != address(0) ? applyPercentage(_productETHPrice, _commission) : 0;
            uint __droplinkedShare = applyPercentage(_productETHPrice, fee);
            // console.log("2");
            payable(_publisher).transfer(__publisherShare);
            // console.log("3");
            payable(droplinkedWallet).transfer(__droplinkedShare);
            // console.log("4");
            payable(issuer.issuer).transfer(__royaltyShare);
            // console.log("5");
            // console.log("6");
            __producerShare -= (__publisherShare + __droplinkedShare + __royaltyShare);
            // console.log("7");
            // now pay the benficiaries
            uint[] memory beneficiaryHashes = droplinkedBase.getBeneficariesList(tokenId, _producer);
            // console.log("8");
            __producerShare = _payBeneficiaries(beneficiaryHashes, _productETHPrice, item.amount, ratio, totalProductsPrice, newProductsPrice, __producerShare);
            // console.log("9");
            payable(_paymentWallet).transfer(__producerShare);
            // console.log("10");
            if (droplinkedToken.getOwnerAmount(tokenId, _producer) < item.amount) revert NotEnoughTokens(tokenId, _producer);
            // console.log("11");
            droplinkedToken.safeTransferFrom(_producer, msg.sender, tokenId, item.amount, "");
            // console.log("12");
            // royalty is already set for this token
            // the product is not purchasable after transfer (because metadata is not set for it)!
            droplinkedBase.setProductType(tokenId, _type);
        }
        // console.log("Transferring remaining funds: %s", remainingFunds);
        // console.log("contract: %s", address(this).balance);
        // console.log("13");
        emit Purchase(memo);
        // console.log("14");
    }
    // price, commission, beneficiaries, ; type can't be changed
    function setMetadataAfterPurchase(uint price, uint commission, Beneficiary[] memory beneficiaries, uint tokenId, address paymentWallet) public{
        if (droplinkedBase.isMetadataSet(tokenId,msg.sender)) revert CannotChangeMetata();
        if (droplinkedToken.getOwnerAmount(tokenId, msg.sender) < 1) revert NotEnoughTokens(tokenId, msg.sender); // <-- if the sender does not own any tokens
        uint[] memory _beneficiaryHashes = new uint[](
            beneficiaries.length
        );
        for (uint i = 0; i < beneficiaries.length; i++) {
            _beneficiaryHashes[i] = droplinkedBase.addBeneficiary(
                beneficiaries[i]
            );
        }
        droplinkedBase.setMetadataAfterPurchase(price, commission, msg.sender, _beneficiaryHashes, tokenId, paymentWallet);
    }

    function setMetadata(uint price, uint commission, Beneficiary[] memory beneficiaries, ProductType _type, uint tokenId, address paymentWallet) private{
        if (droplinkedBase.isMetadataSet(tokenId,msg.sender)) revert CannotChangeMetata();
        uint[] memory _beneficiaryHashes = new uint[](
            beneficiaries.length
        );
        for (uint i = 0; i < beneficiaries.length; i++) {
            _beneficiaryHashes[i] = droplinkedBase.addBeneficiary(
                beneficiaries[i]
            );
        }
        droplinkedBase.setMetadata(price, commission, msg.sender, _beneficiaryHashes, _type, tokenId, paymentWallet);
    }

    function removeMetadata(uint tokenId) public{
        droplinkedBase.removeMetadata(tokenId, msg.sender);
    }

    function _payBeneficiaries(uint[] memory beneficiaries, uint _productETHPrice, uint amount, uint ratio, uint totalProductPrice, uint newProductPrice, uint __producerShare) private returns(uint){
        for (uint j = 0; j < beneficiaries.length; j++) {
            Beneficiary memory _beneficiary = droplinkedBase.getBeneficiary(beneficiaries[j]);
            uint __beneficiaryShare = 0;
            if (_beneficiary.isPercentage){
                    __beneficiaryShare = applyPercentage(_productETHPrice, _beneficiary.value); 
            } else {
                // value based beneficiary, convert to eth and transfer
                __beneficiaryShare = (toETHPrice(
                    _beneficiary.value * amount,
                    ratio
                ) * newProductPrice) / totalProductPrice;
            }
            payable(_beneficiary.wallet).transfer(__beneficiaryShare);
            __producerShare -= __beneficiaryShare;
        }
        return __producerShare;
    }

    // in case eth got sent to this contract or was stuck
    function withdrawFunds() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}