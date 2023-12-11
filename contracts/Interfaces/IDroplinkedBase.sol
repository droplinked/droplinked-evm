//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "../CouponManager.sol";

enum ProductType {
    DIGITAL,
    POD,
    PHYSICAL
}

struct Request {
    uint256 tokenId;
    address producer;
    address publisher;
    bool accepted;
}
struct Beneficiary{
    bool isPercentage; 
    uint256 value;
    address wallet;
}

struct CouponProof {
    uint256[2] _pA;
    uint256[2][2] _pB;
    uint256[2] _pC;
    uint256[3] _pubSignals;
    bool _provided;
}

interface IDroplinkedBase {
    function setRequest(Request calldata req, uint256 requestId) external;
    function getBeneficariesList(uint256 tokenId, address _owner) external view returns (uint256[] memory);
    function getBeneficiary(uint256 _hash) external view returns(Beneficiary memory);
    function addCoupon(
        uint256 _secretHash,
        bool _isPercentage,
        uint256 _value
    ) external;

    function setIsRequested(
        address producer_account,
        address publisher_account,
        uint256 tokenId,
        bool value
    ) external;

    function setMetadata(
        uint256 price,
        uint256 commission,
        address _owner,
        uint256[] memory _beneficiaries,
        ProductType _type,
        uint256 tokenId
    ) external;

    function setPublishersRequests(
        address publisher_account,
        uint256 requestId,
        bool value
    ) external;

    function setProducersRequests(
        address producer_account,
        uint256 requestId,
        bool value
    ) external;

    function setRequestCnt(uint256 value) external;

    function getRequest(uint256 req_id) external view returns (Request memory);

    function getIsRequested(
        address producer_account,
        address publisher_account,
        uint256 tokenId
    ) external view returns (bool);

    function getPublishersRequests(
        address publisher_account,
        uint256 requestId
    ) external view returns (bool);

    function getProducersRequests(
        address producer_account,
        uint256 requestId
    ) external view returns (bool);

    function getRequestCnt() external view returns (uint256); // todo: find a better way

    function setAccepted(uint256 requestId, bool acc) external;

    function addERC20Address(address erc20contract) external;

    function removeERC20Address(address erc20contract) external;

    function isERC20AddressIncluded(
        address erc20contract
    ) external view returns (bool);

    function getMetadata(
        uint256 tokenId,
        address _owner
    ) external view returns (uint256, uint256, ProductType);

    function checkAndGetCoupon(
        CouponProof calldata _proof
    ) external view returns (Coupon memory);
}