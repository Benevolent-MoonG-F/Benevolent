// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid/interfaces/superfluid/ISuperfluid.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@superfluid/interfaces/agreements/IConstantFlowAgreementV1.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {SuperAppBase} from "@superfluid/apps/SuperAppBase.sol";

contract RedirectAll is SuperAppBase, Ownable {

    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address
    ISuperToken private _acceptedToken; // accepted token
    address[2] public _receiver;
    address handlerAddress;

    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken,
        address dao,
        address handler_
    ) {
        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;
        handlerAddress = handler_;
        _receiver[0] = dao;

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
    }

    /**************************************************************************
     * Redirect Logic
     *************************************************************************/

    function currentReceiver()
        external view
        returns (
            uint256 startTime,
            address firstReceiver,
            address secondReceiver,
            int96 flowRate
        )
    {
        (startTime, flowRate,,) = _cfa.getFlow(_acceptedToken, address(this), _receiver[1]);
        firstReceiver = _receiver[0];
        secondReceiver = _receiver[1];

    }

    event ReceiverChanged(address receiver); //what is this?

    /// @dev If a new stream is opened, or an existing one is opened
    function _updateOutflow(bytes calldata ctx)
        private
        returns (bytes memory newCtx)
    {
      newCtx = ctx;
      // @dev This will give me the new flowRate, as it is called in after callbacks
      for (uint96 i = 0; i < _receiver.length; i++){
        int96 netFlowRate = _cfa.getNetFlow(_acceptedToken, address(this));
        (,int96 outFlowRate,,) = _cfa.getFlow(_acceptedToken, address(this), _receiver[0]); // CHECK: unclear what happens if flow doesn't exist.
        int96 inFlowRate = netFlowRate + (outFlowRate * 2);
    
          // @dev If inFlowRate === 0, then delete existing flow.
          if (inFlowRate == int96(0)) {
            // @dev if inFlowRate is zero, delete outflow.
              (newCtx, ) = _host.callAgreementWithContext(
                  _cfa,
                  abi.encodeWithSelector(
                      _cfa.deleteFlow.selector,
                      _acceptedToken,
                      address(this),
                      _receiver[i],
                      new bytes(0) // placeholder
                  ),
                  "0x",
                  newCtx
              );
            } else if (outFlowRate != int96(0)){
            (newCtx, ) = _host.callAgreementWithContext(
                _cfa,
                abi.encodeWithSelector(
                    _cfa.updateFlow.selector,
                    _acceptedToken,
                    _receiver[i],
                    (inFlowRate/2),
                    new bytes(0) // placeholder
                ),
                "0x",
                newCtx
            );
          } else {
          // @dev If there is no existing outflow, then create new flow to equal inflow
              (newCtx, ) = _host.callAgreementWithContext(
                  _cfa,
                  abi.encodeWithSelector(
                      _cfa.createFlow.selector,
                      _acceptedToken,
                      _receiver[i],
                      (inFlowRate/2),
                      new bytes(0) // placeholder
                  ),
                  "0x",
                  newCtx
              );
          }   
      }
    }

    modifier onlyhandler() {
        require(msg.sender == handlerAddress);
        _;
    }

    function changeReceiverAdress(address _newReceiver) external onlyhandler {
       _changeReceiver(_newReceiver);
    }

    // @dev Change the Receiver of the total flow
    function _changeReceiver( address newReceiver ) internal {
        require(newReceiver != address(0), "New receiver is zero address");
        // @dev because our app is registered as final, we can't take downstream apps
        require(!_host.isApp(ISuperApp(newReceiver)), "New receiver can not be a superApp");
        require(newReceiver != _receiver[0] || newReceiver != _receiver[1]);        
        // @dev delete flow to old receiver
    
        (,int96 outFlowRate,,) = _cfa.getFlow(_acceptedToken, address(this), _receiver[0]); //CHECK: unclear what happens if flow doesn't exist.
        if(outFlowRate > 0) {
            for (uint i = 0; i< _receiver.length; i++){
                _host.callAgreement(
                    _cfa,
                    abi.encodeWithSelector(
                        _cfa.deleteFlow.selector,
                        _acceptedToken,
                        address(this),
                        _receiver[i],
                        new bytes(0)
                    ),
                    "0x"
                );
                _receiver[1] = newReceiver;
                // @dev create flow to new receiver
                _host.callAgreement(
                    _cfa,
                    abi.encodeWithSelector(
                        _cfa.createFlow.selector,
                        _acceptedToken,
                        _receiver[i],
                        (_cfa.getNetFlow(_acceptedToken, address(this))/2),
                        new bytes(0)
                    ),
                    "0x"
                );
            }
        // @dev set global receiver to new receiver
        }
        _receiver[1] = newReceiver;

        emit ReceiverChanged(_receiver[1]);
    }

    /**************************************************************************
     * SuperApp callbacks
     *************************************************************************/

    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata /*_agreementData*/,
        bytes calldata ,// _cbdata,
        bytes calldata _ctx
    )
        external override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        return _updateOutflow(_ctx);
    }

    function afterAgreementUpdated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 ,//_agreementId,
        bytes calldata /*agreementData */,
        bytes calldata ,//_cbdata,
        bytes calldata _ctx
    )
        external override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        return _updateOutflow(_ctx);
    }

    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 ,//_agreementId,
        bytes calldata /*_agreementData*/,
        bytes calldata ,//_cbdata,
        bytes calldata _ctx
    )
        external override
        onlyHost
        returns (bytes memory newCtx)
    {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isSameToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;
        return _updateOutflow(_ctx);
    }

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(_acceptedToken);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

    modifier onlyHost() {
        require(msg.sender == address(_host), "RedirectAll: support only one host");
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "RedirectAll: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectAll: only CFAv1 supported");
        _;
    }

}