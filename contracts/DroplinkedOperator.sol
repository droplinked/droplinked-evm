//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "./IERC20.sol";
import "./IDroplinkedToken.sol";
import "./IDroplinkedBase.sol";
import "./DroplinkedBase.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DroplinkedToken.sol";
import "./CouponManager.sol";

// todo: support ERC20 for payment

contract DroplinkedOperator is Ownable {
    error AccessDenied();
    error AlreadyRequested();
    error RequestNotfound();
    error RequestIsAccepted();
    error RequestIsNotAccepted();
    error NotSupportedERC20Token();
    error oldPrice();
    error InvalidAmounts();
    error InvalidCouponValue();
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
    function getLatestPrice(uint80 roundId) public view returns (uint, uint) {
        (, int256 price, , uint256 timestamp, ) = priceFeed.getRoundData(
            roundId
        );
        return (uint(price), timestamp);
    }

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(address _base, address _token) {
        if (_base != address(0)) {
            DroplinkedBase base = new DroplinkedBase();
            droplinkedBase = IDroplinkedBase(address(base));
            base.setOperator(address(this));
            emit DeployedBase(address(base));
        } else {
            droplinkedBase = IDroplinkedBase(_base);
        }
        if (_token != address(0)) {
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
        uint[] memory _beneficiaries,
        TokenType _tokenType
    ) public {
        uint256 tokenId = droplinkedToken.mint(_uri, amount, receiver);
        droplinkedBase.setMetadata(
            _price,
            _commission,
            msg.sender,
            _beneficiaries,
            _tokenType,
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

    // The most important section!
    // No ruleset Version
    function decentralizedPurchase(
        uint80 roundId,
        PurchaseData[] memory purchaseData,
        DirectPurchaseData[] memory directPurchase,
        uint tax,
        uint shipping,
        address _fromAddress,
        CouponProof calldata _proof
    ) public payable noReentrant {
        (uint ratio, uint timestamp) = getLatestPrice(roundId);
        if (
            block.timestamp > timestamp &&
            block.timestamp - timestamp >
            2 * uint(droplinkedToken.getHeartBeat())
        ) revert oldPrice();
        if (_proof._provided) {
            // Coupon Provided
            Coupon memory coupon = droplinkedBase.checkAndGetCoupon(_proof);
            if (coupon.isPercentage) {
                // Percent based
                if (coupon.value > 1e4) revert InvalidCouponValue();
                _purchase(
                    ratio,
                    purchaseData,
                    directPurchase,
                    tax,
                    shipping,
                    coupon.value,
                    _fromAddress,
                    true
                );
                return;
            } else {
                // Value based
                _purchase(
                    ratio,
                    purchaseData,
                    directPurchase,
                    tax,
                    shipping,
                    coupon.value,
                    _fromAddress,
                    false
                );
            }
        } else {
            // Coupon Not provided
            _purchase(
                ratio,
                purchaseData,
                directPurchase,
                tax,
                shipping,
                0,
                _fromAddress,
                false
            );
        }
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

    function _purchase(
        uint ratio,
        PurchaseData[] memory purchaseData,
        DirectPurchaseData[] memory directPurchase,
        uint tax,
        uint shipping,
        uint creditValue,
        address _fromAddress,
        bool isDiscount
    ) private {
        uint totalProductPrice = msg.value - toETHPrice(shipping + tax, ratio);
        uint newProductPrice = _applyCoupon(
            totalProductPrice,
            isDiscount,
            creditValue,
            ratio
        );
        uint fee = droplinkedToken.getFee();

        for (uint i = 0; i < purchaseData.length; i++) {
            PurchaseData memory pdata = purchaseData[i];
            address _producer;
            address _publisher;
            uint _tokenId = 0;
            // INITIAL SECTION---------------------------------------------------
            if (pdata.isAffiliate) {
                if (creditValue != 0) revert CouponCantBeApplied();
                Request memory _req = droplinkedBase.getRequest(
                    pdata.requestId
                );
                if (!_req.accepted) revert RequestIsNotAccepted();
                _producer = _req.producer;
                _publisher = _req.publisher;
                if (_publisher != _fromAddress) revert InvalidFromAddress();
                _tokenId = _req.tokenId;
            } else {
                _producer = _fromAddress;
                _publisher = msg.sender; // does not matter
                _tokenId = pdata.tokenId;
                if (_producer != _fromAddress) revert InvalidFromAddress();
            }
            (uint _productPrice, uint _commission) = droplinkedBase.getMetadata(
                _tokenId,
                _producer
            );
            uint _productETHPrice = (toETHPrice(
                _productPrice * pdata.amount,
                ratio
            ) * newProductPrice) / totalProductPrice;
            uint __publisherShare = applyPercentage(
                _productETHPrice,
                _commission
            );
            uint __droplinkedShare = applyPercentage(_productETHPrice, fee);
            payable(_publisher).transfer(__publisherShare);
            payable(droplinkedWallet).transfer(__droplinkedShare);
            uint __productPriceWithoutPublisher = _productETHPrice -
                __publisherShare -
                __droplinkedShare;

            // BENEFICIARY SECTION------------------------------------------------
            // iterate over benficiaries
            uint[] memory _valueBasedBeneficiaries = droplinkedBase
                .getSelectiveBeneficiaries(_tokenId, _producer, 0);
            uint[] memory _percentBasedBeneficiaries = droplinkedBase
                .getSelectiveBeneficiaries(_tokenId, _producer, 1);
            // Handle value based beneficiaries
            for (uint j = 0; j < _valueBasedBeneficiaries.length; j++) {
                Beneficiary memory _beneficiary = droplinkedBase.getBeneficiary(
                    _valueBasedBeneficiaries[j]
                );
                uint __beneficiaryAmount = toETHPrice(
                    _beneficiary.value,
                    ratio
                );
                payable(_beneficiary._address).transfer(__beneficiaryAmount);
                if (__beneficiaryAmount > __productPriceWithoutPublisher)
                    revert InvalidAmounts();
                __productPriceWithoutPublisher -= __beneficiaryAmount;
            }
            // Handle percentage based beneficiaries
            for (uint j = 0; j < _percentBasedBeneficiaries.length; j++) {
                Beneficiary memory _beneficiary = droplinkedBase.getBeneficiary(
                    _percentBasedBeneficiaries[j]
                );
                uint __beneficiaryAmount = applyPercentage(
                    __productPriceWithoutPublisher,
                    _beneficiary.value
                );
                payable(_beneficiary._address).transfer(__beneficiaryAmount);
                __productPriceWithoutPublisher -= __beneficiaryAmount;
            }
            // --------------------------------------------------------------------

            // Transfer NFT section
            if (
                droplinkedToken.getOwnerAmount(_tokenId, _fromAddress) <
                pdata.amount
            ) revert NotEnoughTokens(_tokenId, _fromAddress);
            droplinkedToken.safeTransferFrom(
                _fromAddress,
                msg.sender,
                _tokenId,
                pdata.amount,
                ""
            );
        }
        // Handle Direct payment data
        for (uint i = 0; i < directPurchase.length; i++) {
            DirectPurchaseData memory dpd = directPurchase[i];
            uint _productETHPrice = toETHPrice(dpd.amount * dpd.price, ratio);
            // just send the product price to the _fromAddress, nothing else is needed (?)
            payable(_fromAddress).transfer(_productETHPrice);
        }
        // Transfer the tax & shipping to producer
        payable(_fromAddress).transfer(tax + shipping);
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}
