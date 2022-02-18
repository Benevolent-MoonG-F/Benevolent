// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IHandler {

    function voteForCharity(bytes8 charity) external;

    function withdrawRoundFunds(uint amount_) external ;

    function acountForDRfnds() external;
    
}