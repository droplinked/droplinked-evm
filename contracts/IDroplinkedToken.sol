//// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IDroplinkedToken{
    function setHeartBeat(uint16 _heartbeat) external;
    function getHeartBeat() external view returns (uint16);
    function droplinked_mint(
        string calldata _uri,
        uint amount,
        address receiver
    ) external returns (uint);
    function setFee(uint _fee) external;
    function DsafeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
}