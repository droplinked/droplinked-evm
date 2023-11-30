//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
struct Request {
    uint256 tokenId;
    address producer;
    address publisher;
    bool accepted;
}
interface IDroplinkedBase {
    function setRequest(Request calldata req, uint256 requestId) external;
    function addCoupon(uint _secretHash, bool _isPercentage, uint _value) external;
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
        uint256 tokenId
    ) external; // needs to be updated! added beneficaries

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

    function getRequestCnt() external view returns (uint256);

    function setAccepted(uint256 requestId, bool acc) external;

    function addERC20Address(address erc20contract) external;

    function removeERC20Address(address erc20contract) external;

    function isERC20AddressIncluded(
        address erc20contract
    ) external view returns (bool);

    function getMetadata(
        uint tokenId,
        address _owner
    ) external view returns (uint, uint);
}
