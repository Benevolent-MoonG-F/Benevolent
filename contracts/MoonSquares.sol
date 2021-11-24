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
    IInstantDistributionAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";

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
    uint monthCount;

    uint payroundStartTime;

    uint128 constant payDayDuration = 30 days;

    uint totalPaid;
    

    address constant IBA = 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e; //should be aave contact address or the IBA to be used
    address DAO; //address of the Dao contact
    address SWAPADRESS;
    address Dai;
    address _aaveToken;
    
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
    
    address[] public winers;
    
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
        payroundStartTime = block.timestamp;


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
    
    modifier isWinner() {
        for (uint i =0; i< winers.length; i++) {
            require(winers[i] == msg.sender);
        }
        _;
    }

    function voteForCharity(bytes8 charity) public isWinner {
        roundCharityVotes[coinRound][charity] += 1;
    }
    
    function addToWinners(address _winner) external {
        winers.push(_winner);
    }
    
   function predictAsset(
       uint256 _start, 
       uint256 coin /* integer for the index of the stablecoin in allowedPayments*/, 
       uint256 _end,
       address[] calldata swapPairs
    ) external nonReentrant returns (bytes memory /*, uint[] memory */)
    {
        uint256 amount;
        uint256 duration = 300 seconds;
        
        if (getPrice() > roundStartPrice[coinRound]) {
            amount = ((getPrice() - roundStartPrice[coinRound]) * 100) + 5 * 10 ** 18;
        } else {
            amount  = 5 * 10 ** 18;
        }

        //remember to add aprove on the ERC20 to the QuickSwap Rrouter
        address(SWAPADRESS).call(
            abi.encodeWithSignature(
                "swapTokensForExactTokens(uint, uint, address[], address, uint)",
                amount,//amount out
                amount,//amount in
                swapPairs, //pairs geting swaped
                msg.sender, 
                1
            )
        );
        //uint[] memory returnValues = address(SWAPADRESS).call(swapload);

        bytes memory payload =abi.encodeWithSignature("deposit(address, uint, address, uint)", Dai, amount, address(this), 0);//should have a protocal referal to use
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
        //roundAssetTotalAmount[coinRound][allowedPayments[coin]] += amount;
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
        //roundCharityContributions[coinRound] = (roundTotalStaked[coinRound] * 7)/100;
        roundWinnings[coinRound] = (roundTotalStaked[coinRound] * 90)/100;
        //roundContractContribution[coinRound] = (roundTotalStaked[coinRound] * 3)/100;
        
        //this.voteForCharity(_charity);
        
        return (returnData /*, returnValues */);
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
                    roundWinningIndex[0], //use addresses
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
        totalPaid += roundWinnings[coinRound];

    }

    function setTime(uint128 _round) private {
        roundWinningTime[_round] = getTime();
        setwinningIndex();
    }

    function getRound() public view returns(uint128) {
        return coinRound;
    }

    function checkUpkeep(
        bytes calldata checkData
    ) external view override returns (
        bool upkeepNeeded, bytes memory performData
    ) {
        if (getPrice() == roundMoonPrice[coinRound]) {
            upkeepNeeded = true;
            return (true, /* address(this).call( */ abi.encodeWithSignature("setTime(uint128)", getRound()));
        }
        if (roundWinningIndex[coinRound].length != 0) {
            upkeepNeeded = true;
            return (true, abi.encodeWithSignature("withdrawRoundFundsFromIba(uint256)", getRound()));//
        }
        if (block.timestamp >= payroundStartTime + 30 days) {
            upkeepNeeded = true;
            return (true, abi.encodeWithSignature("withdrawInterest(address)", _aaveToken));
        }
        performData = checkData;
        
    }

    function performUpkeep(bytes calldata performData) external override {
        performData;
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
    function withdrawRoundFundsFromIba(uint128 _round) private returns (bytes memory) {
        //if (getPrice() == roundMoonPrice[_round]) {
            bytes memory payload =abi.encodeWithSignature("withdraw(address, uint, address)", Dai, roundWinnings[_round], address(this));
            (bool success, bytes memory returnData) = address(IBA).call(payload);
            require(success);
                
            /* IBA.withdraw(
                allowedPayments[i],
                roundAssetTotalAmount[coinRound][allowedPayments[i]],
                address(this)
            ); */
            return returnData;
        //}
        //Withdraws Funds from the predictions and the interest earned
    }

    function withdrawInterest(address aaveToken) private returns(uint, bytes memory) {
        uint aaveBalance = IERC20(aaveToken).balanceOf(msg.sender);
        uint interest = aaveBalance - (roundTotalStaked[coinRound] - totalPaid);
        bytes memory payload = abi.encodeWithSignature(
            "withdraw(address, uint, address)",
            Dai,
            interest,
            address(this)
        );
        (bool success, bytes memory returnData) = address(IBA).call(payload);
        require(success);
        return(interest, returnData);

    }

    //sends the rounds's charity donations to the winning charity

    //distributes the Interest Earned on the round to members of the Dao
    function flowToDao(/*uint256 _round,*/ bytes calldata ctx) external returns(bytes memory newCtx){
        //Flows interest earned from the protocal to the redirectAll contract that handles distribution
        int96 inFlowRate;
        newCtx = ctx;
            //Flow Winnings
        (newCtx, ) = _host.callAgreementWithContext(
            _cfa,
            abi.encodeWithSelector(
                _cfa.createFlow.selector,
                _acceptedToken,
                DAO,
                inFlowRate, //should be the total amount of Interest withdrawnfrom the IBA divided by the number of seconds in the withdrawal interval
                new bytes(0) // placeholder
            ),
            "0x",
            newCtx
        );
    }
}