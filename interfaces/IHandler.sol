// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IHandler {

    function voteForCharity(string memory charity) external;

    function withdrawRoundFunds(uint amount_) external ;

    function acountForDRfnds() external;

    function addGovernanceToken(address _gtAdress) external;   
    
    function addFlowDistributor(address addr) external;
    
}