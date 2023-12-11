//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "./Interfaces/IERC20.sol";
import "./Interfaces/IDroplinkedToken.sol";
import "./Interfaces/IDroplinkedBase.sol";
import "./DroplinkedBase.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DroplinkedToken.sol";
import "./CouponManager.sol";

// todo: support ERC20 for payment

contract DroplinkedOperator is Ownable, ReentrancyGuard {
    error AccessDenied();
    error InvalidFee(uint fee);
    error ProductTypeMismatch();
    error AlreadyRequested();
    error RequestNotfound();
    error RequestIsAccepted();
    error InvalidCoupon();
    error DroplinkedShareNotIncluded();
    error InvalidDroplinkedShare();
    error RequestIsNotAccepted();
    error NotSupportedERC20Token();
    error oldPrice();
    error AffiliatePOD();
    error InvalidAmounts();
    error DifferentLength();
    error InvalidCouponValue();
    error InvalidTaxAndShippingForDigitalProducts();
    error InvalidPublisher();
    error CouponCantBeApplied();
    error NotEnoughTokens(uint tokenId, address tokenOwner);
    error ERC20TransferFailed(uint amount, address receiver);
    error InvalidFromAddress();

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

    address public immutable droplinkedWallet =
        0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78;

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
            droplinkedBase = IDroplinkedBase(address(base));
            base.setOperator(address(this));
            emit DeployedBase(address(base));
        } else {
            droplinkedBase = IDroplinkedBase(_base);
        }
        if (_token == address(0)) {
            DroplinkedToken token = new DroplinkedToken();
            droplinkedToken = IDroplinkedToken(address(token));
            token.setOperator(address(this));
            emit DeployedToken(address(token));
        } else {
            droplinkedToken = IDroplinkedToken(_token);
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
        uint[] memory _beneficiaries
    ) public {
        uint256 tokenId = droplinkedToken.mint(_uri, amount, receiver);
        droplinkedBase.setMetadata(
            _price,
            _commission,
            msg.sender,
            _beneficiaries,
            _type,
            tokenId
        );
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
    }

    function removeERC20Contract(address erc20token) public onlyOwner {
        droplinkedBase.removeERC20Address(erc20token);
    }

    struct PurchaseData {
        // ==> For affiliate and recorded products
        uint tokenId;
        uint amount;
        uint requestId;
        bool isAffiliate;
    }

    struct DirectPurchaseData {
        // ==> For direct payment and non recorded products
        uint amount;
        uint price; // 100x
    }

    function toETHPrice(uint value, uint ratio) public pure returns (uint) {
        return (1e24 * value) / ratio;
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
            newProductPrice = applyPercentage(totalProductPrice, couponValue);
        }
        return newProductPrice;
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

    // affiliate products must have same publisher => done
    // non recorded products are free => done
    // note with checking coupon => coupon can only be applied to products that the owner has published the coupon with
    // note => emit events after payments are done!

    function recordedPurchase(uint80 roundId, uint[] memory tokenIds, uint[] memory amounts,uint _tax, uint _shipping, address fromAddress, CouponProof calldata proof) public payable{
        // todo: move the beneficiary giving to another function for clearity & reuse!
        require (amounts.length == tokenIds.length, "Different length of tokens and amounts"); 
        require(tokenIds.length != 0, "No items in cart");
        // get price ratio and check if roundId is valid (not past of 2 heartbeats)
        
        (uint ratio, uint timestamp) = getLatestPrice(roundId);
        if (
            block.timestamp > timestamp &&
            block.timestamp - timestamp >
            2 * uint(droplinkedToken.getHeartBeat())
        ) revert oldPrice();

        bool isDiscount = false;
        (,, ProductType _type) = droplinkedBase.getMetadata(tokenIds[0], fromAddress);        
        uint _couponValue = 0;
        // validate coupon and get _couponValue from it
        if (proof._provided){
            Coupon memory coupon = droplinkedBase.checkAndGetCoupon(proof);
            if (coupon.couponProducer != fromAddress) revert InvalidCoupon();
            isDiscount = coupon.isPercentage;
            _couponValue = coupon.value;
            if (coupon.couponProducer != fromAddress) revert InvalidCoupon();
        }
        // Since this is the recorded products, the affiliate check for coupon is redundant
        // if (affiliate & creditValue > 0) revert CannotApplyCoupon();

        uint tax = toETHPrice(_tax, ratio);
        uint shipping = toETHPrice(_shipping, ratio);

        uint totalProductPrice = msg.value - toETHPrice(shipping + tax, ratio);
        uint newProductPrice = _applyCoupon(totalProductPrice, isDiscount, _couponValue, ratio);
        uint fee = droplinkedToken.getFee();

        for (uint i = 0; i < tokenIds.length; i++) {
            // no commission in recorded payment, only the type of the product an its price matters, also if the types are different revert
            (uint _productPrice,, ProductType _productType) = droplinkedBase.getMetadata(tokenIds[i],fromAddress);
            if (_productType != _type) revert ProductTypeMismatch();
            // calculate the product price based on the ratio and the coupon
            uint _productETHPrice = (toETHPrice(
                _productPrice * amounts[i],
                ratio
            ) * newProductPrice) / totalProductPrice;
            uint __producerShare = _productETHPrice;
            uint __droplinkedShare = applyPercentage(_productETHPrice, fee);
            payable(droplinkedWallet).transfer(__droplinkedShare);
            __producerShare -= __droplinkedShare;
            __producerShare = _payBeneficiaries(droplinkedBase.getBeneficariesList(tokenIds[i], fromAddress), _productETHPrice, amounts[i], ratio, totalProductPrice, newProductPrice, __producerShare);
            payable(fromAddress).transfer(__producerShare);
            // transfer nfts after payment
            // check if the producer has amounts[i] from tokenIds[i]:
            if (droplinkedToken.getOwnerAmount(tokenIds[i], fromAddress) < amounts[i]) revert NotEnoughTokens(tokenIds[i], fromAddress);
            droplinkedToken.safeTransferFrom(fromAddress, msg.sender, tokenIds[i], amounts[i], "");
        }
        // tax & shipping part
        if (_type == ProductType.POD){
            // tax & shipping is for droplinked
            payable(droplinkedWallet).transfer(tax + shipping);
        } else if (_type == ProductType.PHYSICAL){
            // tax & shipping is for producer
            payable(fromAddress).transfer(tax + shipping);
        } else if (_type == ProductType.DIGITAL){
            // digital products are free of tax & shipping, so if they were not zero, revert
            if (tax != 0 || shipping != 0) revert InvalidTaxAndShippingForDigitalProducts();
        }
    }

    // tax and shipping must be included in values and recievers
    // the prices are given as usd amount * 100
    function nonRecordedPurchase(uint80 roundId, uint[] memory values, address[] memory receivers) public payable nonReentrant{
        if (values.length != receivers.length) revert DifferentLength();
        // transfer 1% to the droplinked wallet (it should be included in values[0], _recivers[0])
        (uint ratio, uint timestamp) = getLatestPrice(roundId);
        if (
            block.timestamp > timestamp &&
            block.timestamp - timestamp >
            2 * uint(droplinkedToken.getHeartBeat())
        ) revert oldPrice();
        if (receivers[0] != droplinkedWallet) revert DroplinkedShareNotIncluded();
        if ((msg.value/100) > toETHPrice(values[0], ratio)) revert InvalidDroplinkedShare();
        for (uint i = 0; i < values.length; i++) {
            payable(receivers[i]).transfer(toETHPrice(values[i], ratio));
        }
    }

    // no coupon for affiliate payment
    function affiliatePurchase(uint80 roundId, uint[] memory requestIds, uint[] memory amounts, address publisher, uint _tax, uint _shipping) public payable nonReentrant{
        if (requestIds.length != amounts.length) revert DifferentLength();
        (uint ratio, uint timestamp) = getLatestPrice(roundId);
        if (
            block.timestamp > timestamp &&
            block.timestamp - timestamp >
            2 * uint(droplinkedToken.getHeartBeat())
        ) revert oldPrice();
        uint fee = droplinkedToken.getFee();
        uint tax = toETHPrice(_tax, ratio);
        uint shipping = toETHPrice(_shipping, ratio);
        uint totalProductPrice = msg.value - toETHPrice(shipping + tax, ratio);
        Request memory req = droplinkedBase.getRequest(requestIds[0]);
        (,, ProductType _type) = droplinkedBase.getMetadata(req.tokenId, req.producer);
        if (_type == ProductType.POD) revert AffiliatePOD();
        for (uint i = 0; i < requestIds.length; i++) {
            req = droplinkedBase.getRequest(requestIds[i]);
            if (req.publisher != publisher) revert InvalidPublisher();
            (uint _productPrice,uint _commission, ProductType _productType) = droplinkedBase.getMetadata(req.tokenId, req.producer);
            if (_productType != _type) revert ProductTypeMismatch();
            uint _productETHPrice = (toETHPrice(
                _productPrice * amounts[i],
                ratio
            ));
            uint __producerShare = _productETHPrice;
            uint __publisherShare = applyPercentage(_productETHPrice, _commission);
            __producerShare -= __publisherShare;
            uint __droplinkedShare = applyPercentage(_productETHPrice, fee);
            payable(droplinkedWallet).transfer(__droplinkedShare);
            __producerShare -= __droplinkedShare;
            __producerShare = _payBeneficiaries(droplinkedBase.getBeneficariesList(req.tokenId, req.producer), _productETHPrice, amounts[i], ratio, totalProductPrice, totalProductPrice, __producerShare);
            payable(req.producer).transfer(__producerShare);
            payable(publisher).transfer(__publisherShare);
            // transfer nfts after payment
            // check if the producer has amounts[i] from tokenIds[i]:
            if (droplinkedToken.getOwnerAmount(req.tokenId, req.producer) < amounts[i]) revert NotEnoughTokens(req.tokenId, req.producer);
            droplinkedToken.safeTransferFrom(req.producer, msg.sender, req.tokenId, amounts[i], "");
        }
        // tax & shipping part, for POD it was checked before
        if (_type == ProductType.PHYSICAL){
            // tax & shipping is for producer
            payable(req.producer).transfer(tax + shipping);
        } else if (_type == ProductType.DIGITAL){
            // digital products are free of tax & shipping, so if they were not zero, revert
            if (tax != 0 || shipping != 0) revert InvalidTaxAndShippingForDigitalProducts();
        }
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}
