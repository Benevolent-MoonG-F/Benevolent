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
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

contract RedirectAll is SuperAppBase, Ownable {

    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address
    ISuperToken private _acceptedToken; // accepted token
    address[] public _receiver;
    address MoonSquareAddress;

    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken,
        //address dev,
        address dao,
        address moon) {
        require(address(host) != address(0), "host is zero address");
        require(address(cfa) != address(0), "cfa is zero address");
        require(address(acceptedToken) != address(0), "acceptedToken is zero address");
        //require(address(dev) != address(0), "receiver is zero address");
        //require(!host.isApp(ISuperApp(dev)), "receiver is an app");

        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;
        MoonSquareAddress = moon;
        //_receiver.push(dev);
        _receiver.push(dao);

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
    }
    //Superfluidhost = mumbai(0xEB796bdb90fFA0f28255275e16936D25d3418603), mainet(0x3E14dC1b13c488a8d5D310918780c983bD5982E7)
    //ida = mumbai(0x804348D4960a61f2d5F9ce9103027A3E849E09b8), mainet(0xB0aABBA4B2783A72C52956CDEF62d438ecA2d7a1)
    //cfa = mumbai(0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873), mainet(0x6EeE6060f715257b970700bc2656De21dEdF074C)
    //fDai = mumbai(0x15F0Ca26781C3852f8166eD2ebce5D18265cceb7)
    //fDaix = mumbai(0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f)
    //Dai = mainet(0x8f3cf7ad23cd3cadbd9735aff958023239c6a063)
    //Daix = mainet(0x1305F6B6Df9Dc47159D12Eb7aC2804d4A33173c2)

    function addReceiver(address _dev) public onlyOwner {
        require(_receiver.length < 3);
        _receiver.push(_dev);
    }


    /**************************************************************************
     * Redirect Logic
     *************************************************************************/

    function currentReceiver()
        external view
        returns (
            uint256 startTime,
            address[] memory receiver,
            int96 flowRate
        )
    {
        for (uint i = 0; i < _receiver.length; i++){
            if (_receiver[i] != address(0)) {
                (startTime, flowRate,,) = _cfa.getFlow(_acceptedToken, address(this), _receiver[i]);
                receiver = _receiver;
            }
        }

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
        int96 inFlowRate = netFlowRate + (outFlowRate * 3);
    
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
                    (inFlowRate/3),
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
                      (inFlowRate/3),
                      new bytes(0) // placeholder
                  ),
                  "0x",
                  newCtx
              );
          }   
      }
    }

    modifier onlyMoonSquares() {
        require(msg.sender == MoonSquareAddress);
        _;
    }

    function changeReceiverAdress(address _newReceiver) external onlyMoonSquares {
       _changeReceiver(_newReceiver);
    }

    // @dev Change the Receiver of the total flow
    function _changeReceiver( address newReceiver ) internal {
        require(newReceiver != address(0), "New receiver is zero address");
        // @dev because our app is registered as final, we can't take downstream apps
        require(!_host.isApp(ISuperApp(newReceiver)), "New receiver can not be a superApp");
        for (uint i=0; i< _receiver.length; i++) {
            require(newReceiver != _receiver[i]);
            if (newReceiver == _receiver[i]) return ;
    
        
        // @dev delete flow to old receiver
        
            (,int96 outFlowRate,,) = _cfa.getFlow(_acceptedToken, address(this), _receiver[0]); //CHECK: unclear what happens if flow doesn't exist.
            if(outFlowRate > 0){
              _host.callAgreement(
                  _cfa,
                  abi.encodeWithSelector(
                      _cfa.deleteFlow.selector,
                      _acceptedToken,
                      address(this),
                      _receiver[2],
                      new bytes(0)
                  ),
                  "0x"
              );
              // @dev create flow to new receiver
              _host.callAgreement(
                  _cfa,
                  abi.encodeWithSelector(
                      _cfa.createFlow.selector,
                      _acceptedToken,
                      newReceiver,
                      (_cfa.getNetFlow(_acceptedToken, address(this))/3),
                      new bytes(0)
                  ),
                  "0x"
              );
            }
            // @dev set global receiver to new receiver
            _receiver[3] = newReceiver;
    
            emit ReceiverChanged(_receiver[2]);
        }
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