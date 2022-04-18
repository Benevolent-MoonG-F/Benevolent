// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;
interface IFactory {
    function addDRaddress(string memory asset_, address contract_) external;

    function addMSaddress(string memory asset_, address contract_) external;
}