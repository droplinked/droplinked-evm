//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "../CouponManager.sol";
import "../structs.sol";

interface IDroplinkedBase {
    function addBeneficiary(Beneficiary calldata beneficary) external returns (uint);
    function setRequest(Request calldata req, uint256 requestId) external;
    function getBeneficariesList(uint256 tokenId, address _owner) external view returns (uint256[] memory);
    function getBeneficiary(uint256 _hash) external view returns(Beneficiary memory);
    function addCoupon(
        uint256 _secretHash,
        bool _isPercentage,
        uint256 _value
    ) external;

    function removeCoupon(uint secretHash) external;

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
        uint256 tokenId,
        address _paymentWallet
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
    function isMetadataSet(uint tokenId, address owner) external view returns (bool);
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

    function getRequestCnt() external view returns (uint256); // TODO: find a better way

    function setAccepted(uint256 requestId, bool acc) external;

    function addERC20Address(address erc20contract) external;

    function setIssuer(uint tokenId, address issuer, uint royalty) external;

    function getIssuer(uint tokenId) external returns(Issuer memory);

    function removeERC20Address(address erc20contract) external;

    function isERC20AddressIncluded(
        address erc20contract
    ) external view returns (bool);

    function getMetadata(
        uint256 tokenId,
        address _owner
    ) external view returns (uint256, uint256, ProductType, address);

    function checkAndGetCoupon(
        CouponProof calldata _proof
    ) external view returns (Coupon memory);
}
