// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IHandler {
    function upgradeToken(uint256 amount) external;
    
    function createFlow(int96 flowRate) external;
}