//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMoonSquares {

  function setMoonPrice(int price, string memory market) external;

  function predictAsset(uint256 _start, string memory market) external;

}