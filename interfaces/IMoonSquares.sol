//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMoonSquares {

  function voteForCharity(bytes8 charity) external;

  function acountForDRfnds(uint amount) external ; //adds the funds deposited to Aave from DR

  function addGovernanceToken(address _gtAdress) external;

  function addFlowDistributor(address addr) external;

  function setMoonPrice(int price, string memory market) external;

  function addCharity(bytes8 _charityName, address _charityAddress, bytes32 _link) external;

  function addAssetsAndAggregators(string memory _asset, address _aggregator) external;

  function predictAsset(uint256 _start, string memory market) external;

}