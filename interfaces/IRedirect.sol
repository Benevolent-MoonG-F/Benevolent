// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRedirect {

    function changeReceiverAdress(address _newReceiver) external;
}