//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';


import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";


import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";


//make it a super app to allow using superfluid flows and instant distribution
contract MoonSquares is SuperAppBase, KeeperCompatibleInterface, Ownable, ReentrancyGuard {
    
    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address
    
    //the Super token used to pay for option premium (sent directly to the NFT and redirected to owner of the NFT)
    ISuperToken public _acceptedToken; // accepted token, could be the aToken 


    IERC20[] public allowedPayments;//list of all accepted stablecoins for placing a prediction

    uint128 public coinRound;
    

    address constant IBA = 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e; //should be aave contact address or the IBA to be used
    address DAO; //address of the Dao contact
    
    mapping (uint256 => uint256) public roundStartPrice;

    mapping(uint256 => mapping(IERC20 => uint256)) roundAssetTotalAmount;
    
    mapping (uint256 => uint256) roundInterestEarned;

    mapping (uint256 => uint256) public roundCharityContributions; //7% chaitable donations per asset 

    mapping (uint256 => uint256) public roundWinnings;//90% player winning per asset

    mapping (uint256 => uint256) public roundContractContribution; //3% paid to the contract per asset

    //The target price (moon price) every round per asset
    mapping (uint256 => uint256) public roundMoonPrice;

    //when the rallyprice get's set
    mapping (uint256 => uint256) public roundStartTime;

    //Total staked on the contract
    mapping (uint256 => uint256) public roundTotalStaked;

    //time when the price is first hit 
    mapping (uint256 => uint256) public roundWinningTime;
    
    //sample bet
    //structure of the bet
    struct Bet {
        uint256 squareStartTime;
        uint256 squareEndTime;
    }
    
    struct Charity {
        bytes8 name;
        bytes32 link; //sends people to the charity's official site
    }

    mapping (address => Charity) public presentCharities;

    bytes8[] charities;
    address[] charityAddress;
    
    mapping(uint128 => mapping(bytes8 => uint128)) public roundCharityVotes;
    
    mapping(uint128 => bytes8) roundVoteResults;

    //efficient way to store the arrays
    

    mapping (uint256 => address[]) roundPlayerArray;

    mapping (uint256 => uint256[]) roundStartTimeArray;

    mapping (uint256 => uint256[]) roundEndTimeArray;
    
    mapping(uint256 => uint256[]) public roundWinningIndex;

    mapping (uint256 => mapping (address => Bet)) public roundAddressBetsPlaced;

    mapping (address => uint256) totalAmountPlayed;//shows how much every player has placed
    
    address[] public _receiver;
    
    
    constructor(
        
        //set superfluid specific params, receiver, and accepted token in the constructor
        
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken,
        address receiver) {
        require(address(host) != address(0));
        require(address(cfa) != address(0));
        require(address(acceptedToken) != address(0));
        require(address(receiver) != address(0));
        require(!host.isApp(ISuperApp(receiver)));

        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;
        _receiver.push(receiver);


        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
    }

    function addpaymentToken(IERC20 _add) public onlyOwner {
        allowedPayments.push(_add);
    }

    function addCharity(bytes8 _charityName, address _charityAddress, bytes32 _link) public onlyOwner {
        presentCharities[_charityAddress].name = _charityName;
        presentCharities[_charityAddress].link = _link;
        charities.push(_charityName);
        charityAddress.push(_charityAddress);
    }

    function voteForCharity(bytes8 charity) internal {
        roundCharityVotes[coinRound][charity] += 1;
    }
    
   function predictAsset(uint256 _start, uint256 coin /* integer for the index of the stablecoin in allowedPayments*/, uint256 _end) external nonReentrant returns (bytes memory){
        uint256 amount;
        uint256 duration = 300 seconds;
        
        if (getPrice() > roundStartPrice[coinRound]) {
            amount = ((getPrice() - roundStartPrice[coinRound]) * 100) + 5 * 10 ** 18;
        } else {
            amount  = 5 * 10 ** 18;
            
        }
        
        bytes memory payload =abi.encodeWithSignature("deposit(address, uint, address, uint)", allowedPayments[coin], amount, address(this), 0);
        (bool success, bytes memory returnData) = address(IBA).call(payload);
        require(success);
        
        /* IBA.deposit(
            allowedPayments[coin],
            amount,
            address(this),
            0
        ); */
/*
        //transfer stablecoin
        allowedPayments[coin].approve(address(this), amount);
        allowedPayments[coin].transferFrom(msg.sender, address(this), amount);
*/
        roundAssetTotalAmount[coinRound][allowedPayments[coin]] += amount;
        //Dai.transferFrom(msg.sender, address(this), amount);
        //update the betsPlaced mapping
        roundAddressBetsPlaced[coinRound][msg.sender].squareStartTime = _start;
        
        roundAddressBetsPlaced[coinRound][msg.sender].squareEndTime 
        = 
        roundAddressBetsPlaced[coinRound][msg.sender].squareStartTime + duration;
        //update all the relevant arrays
        roundPlayerArray[coinRound].push(msg.sender);
        roundStartTimeArray[coinRound].push(_start);
        roundEndTimeArray[coinRound].push(_end);
        //update the total value played
        roundTotalStaked[coinRound] += amount;
        roundCharityContributions[coinRound] = (roundTotalStaked[coinRound] * 7)/100;
        roundWinnings[coinRound] = (roundTotalStaked[coinRound] * 90)/100;
        roundContractContribution[coinRound] = (roundTotalStaked[coinRound] * 3)/100;
        
        return returnData;
    }

    function getPrice() internal view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        (,int256 answer,,,) = priceFeed.latestRoundData();
        return uint256(answer * 10000000000);
    }

    function getTime() public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
        //kovan network
        (,,,uint256 answer,) = priceFeed.latestRoundData();
         return uint256(answer * 10000000000);
    }

    function setwinningIndex() internal {
        /* we iterate over the squareStartTimeArray(of squareStartTime) and the squareEndTimeArray (of squareEndTime) to assertain that the winning time 
           is either equal to them or more than the squareStartTime but less than the squareEndTime
        */
        require(
            roundEndTimeArray[coinRound].length
            ==
            roundStartTimeArray[coinRound].length
        );
        for (uint256 p =0; p < roundStartTimeArray[coinRound].length; p++) {
            require(
                roundStartTimeArray[coinRound][p] >= roundWinningTime[coinRound]
                &&
                roundEndTimeArray[coinRound][p] <= roundWinningTime[coinRound]    
            );
            roundWinningIndex[coinRound].push(p);
            //round coin start time array of p to be greater or equal to the round coin winning time
        }
        //since squares will be owned by more than one person, we set the index to allow us to delagate the claiming reward function to the user.
    }

    //should use superflid's flow if its just one user & instant distribution if there are several winners
     function givePrize(uint256 _round, bytes calldata ctx) internal returns (bytes memory newCtx) {
        require(roundWinningIndex[_round].length != 0);
        int96 inFlowRate;
        newCtx = ctx;
        if (roundWinningIndex[_round].length == 1) {
            //Flow Winnings
            (newCtx, ) = _host.callAgreementWithContext(
                _cfa,
                abi.encodeWithSelector(
                    _cfa.createFlow.selector,
                    _acceptedToken,
                    roundWinningIndex[0],
                    inFlowRate,
                    new bytes(0) // placeholder
                ),
                "0x",
                newCtx
            );
        } else {
            for (uint8 i = 0; i < roundWinningIndex[_round].length; i++) {
                require(roundPlayerArray[_round][roundWinningIndex[_round][i]] == msg.sender);
                //Instant Distribution Logic
            }
        }

    }

    function checkUpkeep(
        bytes calldata checkData
    ) external view override returns (
        bool upkeepNeeded, bytes memory performData
    ) {
        if (getPrice() == roundMoonPrice[coinRound]) {
            upkeepNeeded = true;
            return (true, performData) ;
        }
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        roundWinningTime[coinRound] = getTime();
        setwinningIndex();
    }

    function tokenIsAccepted(IERC20 _token) public view returns (bool) {
        for(uint i =0; i < allowedPayments.length; i++) {
            if(allowedPayments[i] == _token){
                return true;
            } else {
                return false;
            }
        }
    }

    function setwinningCharity() internal{
        uint128 winning_votes = 0;
        for (uint i =0; i < charities.length; i++) {
            if (roundCharityVotes[coinRound][charities[i]] > winning_votes){
                winning_votes == roundCharityVotes[coinRound][charities[i]];
                roundVoteResults[coinRound] = charities[i];
            }
        }
        //return charities[i];
    }

    //withdraws the total Amount after the moonpice gets hit
    function withdrawRoundFundsFromIba(/*uint256 _round*/) private returns (bytes memory) {
        //if (getPrice() == roundMoonPrice[_round]) {
        for (uint i = 0; i < allowedPayments.length; i++) {
                
            bytes memory payload =abi.encodeWithSignature("withdraw(address, uint, address)", allowedPayments[i], ((roundAssetTotalAmount[coinRound][allowedPayments[i]] * 90)/ 100), address(this));
            (bool success, bytes memory returnData) = address(IBA).call(payload);
            require(success);
                
            /* IBA.withdraw(
                allowedPayments[i],
                roundAssetTotalAmount[coinRound][allowedPayments[i]],
                address(this)
            ); */
            return returnData;
        }
        //}
        //Withdraws Funds from the predictions and the interest earned
    }

    //sends the rounds's charity donations to the winning charity
    function sendToWinningCharity(uint256 _round) internal {
        //Flow
    }

    //distributes the Interest Earned on the round to members of the Dao
    function flowToDao(uint256 _round) internal {
        //Flow
    }

    function flowToDevs(uint256 _round) internal {
        //Instant Distribution
    }
    
    function currentReceiver()
        external view
        returns (
            uint256 startTime,
            address[]memory receiver,
            int96 flowRate
        )
    {
        for (uint i =0; i < _receiver.length; i++) {
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
      int96 netFlowRate = _cfa.getNetFlow(_acceptedToken, address(this));
      (,int96 outFlowRate,,) = _cfa.getFlow(_acceptedToken, address(this), _receiver[1]); // CHECK: unclear what happens if flow doesn't exist.
      int96 inFlowRate = netFlowRate + outFlowRate;

      // @dev If inFlowRate === 0, then delete existing flow.
      if (inFlowRate == int96(0)) {
        // @dev if inFlowRate is zero, delete outflow.
          (newCtx, ) = _host.callAgreementWithContext(
              _cfa,
              abi.encodeWithSelector(
                  _cfa.deleteFlow.selector,
                  _acceptedToken,
                  address(this),
                  _receiver,
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
                _receiver,
                inFlowRate,
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
                  _receiver,
                  inFlowRate,
                  new bytes(0) // placeholder
              ),
              "0x",
              newCtx
          );
      }
    }

    // @dev Change the Receiver of the total flow
    function _changeReceiver( address newReceiver ) internal {
        require(newReceiver != address(0));
        // @dev because our app is registered as final, we can't take downstream apps
        require(!_host.isApp(ISuperApp(newReceiver)));
        if (newReceiver == _receiver[3]) return ;
        // @dev delete flow to old receiver
        (,int96 outFlowRate,,) = _cfa.getFlow(_acceptedToken, address(this), _receiver[3]); //CHECK: unclear what happens if flow doesn't exist.
        if(outFlowRate > 0){
          _host.callAgreement(
              _cfa,
              abi.encodeWithSelector(
                  _cfa.deleteFlow.selector,
                  _acceptedToken,
                  address(this),
                  _receiver,
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
                  _cfa.getNetFlow(_acceptedToken, address(this)),
                  new bytes(0)
              ),
              "0x"
          );
        }
        // @dev set global receiver to new receiver
        _receiver[3] = newReceiver;

        emit ReceiverChanged(_receiver[3]);
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
        bytes calldata agreementData,
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