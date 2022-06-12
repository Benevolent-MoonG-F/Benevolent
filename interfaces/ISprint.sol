// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface ISprint {
    function setWinningOrder() external;

    function s_assetIdentifier(uint8 _assetId) external view returns (uint256);
}
