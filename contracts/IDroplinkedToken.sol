//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IDroplinkedToken{
    function setHeartBeat(uint16 _heartbeat) external;
    function getHeartBeat() external view returns (uint);
    function mint(
        string calldata _uri,
        uint amount,
        address receiver
    ) external returns (uint);
    function setFee(uint _fee) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
    function getOwnerAmount(uint tokenId, address owner) external view returns (uint);
    function getTokenCnt() external view returns (uint);
    function getTokenIdByHash(bytes32 metadataHash) external view returns (uint);
    function getTokenAmount(uint tokenId) external view returns (uint);
    function getTotalSupply() external view returns (uint);
    function getFee() external view returns (uint);
}