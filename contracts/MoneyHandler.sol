// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;


import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid/interfaces/agreements/IConstantFlowAgreementV1.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MoneyHandler is Ownable {
    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address 
    
    //the Super token used to pay for option premium (sent directly to the NFT and redirected to owner of the NFT)
    ISuperToken private _acceptedToken; // accepted token, 0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09
    address private flowDistrubuter;
    address private Dai;

    constructor(
        ISuperfluid host,//0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3
        IConstantFlowAgreementV1 cfa,//0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F
        ISuperToken acceptedToken,//0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09
        address dai,
        address _dist 
    ) 
    {
        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;
        Dai = dai;
        flowDistrubuter = _dist;
    }

    function upgradeToken(uint256 amount) external onlyOwner {
        IERC20(Dai).approve(address(_acceptedToken), amount);
        _acceptedToken.upgrade(amount);
    }
    function createFlow(int96 flowRate) external onlyOwner {
        _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.createFlow.selector,
                _acceptedToken,
                flowDistrubuter,//address to the distributer that sends funds to charity and Dao
                flowRate, //should be the total amount of Interest withdrawnfrom the IBA divided by the number of seconds in the withdrawal interval
                new bytes(0) // placeholder
            ),
            "0x"
        );
    }
}