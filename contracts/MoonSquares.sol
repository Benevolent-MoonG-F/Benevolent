//Change receiver
//Distribute to Dao members
//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
contract MoonSquares is SuperAppBase, KeeperCompatibleInterface, Ownable {
    
    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address 
    
    //the Super token used to pay for option premium (sent directly to the NFT and redirected to owner of the NFT)
    ISuperToken public _acceptedToken; // accepted token, could be the aToken 


    address[] public allowedPayments;//list of all accepted stablecoins for placing a prediction

    address[] public contracts;

    uint128 public coinRound;

    uint128 monthCount;

    uint payroundStartTime;

    uint128 constant payDayDuration = 30 days;

    uint totalPaid;

    uint32 public constant PAYMENT_INDEX = 0;
    

    address constant IBA = 0x9198F13B08E299d85E096929fA9781A1E3d5d827; //should be aave contact address or the IBA to be used
    address DAO; //address of the Dao contact
    address flowDistrubuter;
    address constant SWAPADRESS = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address Dai = 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa;
    address _aaveToken;
    address governanceToken;
    
    mapping (uint256 => int256) public roundStartPrice;

    mapping(uint256 => mapping(IERC20 => uint256)) roundAssetTotalAmount;
    
    mapping (uint256 => uint256) roundInterestEarned;

    mapping (uint256 => uint256) public roundWinnings;//90% player winning per asset

    //The target price (moon price) every round per asset
    mapping (uint256 => int256) public roundMoonPrice;

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
    
    mapping(uint128 => address) roundVoteResults;

    //efficient way to store the arrays
    
    mapping (uint128 => address[]) public winers;
    
    mapping (uint256 => address[]) roundPlayerArray;

    mapping (uint256 => uint256[]) roundStartTimeArray;

    mapping (uint256 => uint256[]) roundEndTimeArray;
    
    mapping(uint256 => uint256[]) public roundWinningIndex;

    mapping (uint256 => mapping (address => Bet)) public roundAddressBetsPlaced;

    mapping (address => uint256) totalAmountPlayed;//shows how much every player has placed

    event Predicted(address indexed _placer, uint256 _start, uint _end);
    

    constructor(
        
        //set superfluid specific params, receiver, and accepted token in the constructor
        
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken
        ) {
        require(address(host) != address(0));
        require(address(cfa) != address(0));
        require(address(acceptedToken) != address(0));
        //require(address(receiver) != address(0));
        //require(!host.isApp(ISuperApp(receiver)));

        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;
        payroundStartTime = block.timestamp;


        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);

    }

    function addpaymentToken(address _add) external onlyOwner {
        allowedPayments.push(_add);
    }

    function addCharity(bytes8 _charityName, address _charityAddress, bytes32 _link) external onlyOwner {
        presentCharities[_charityAddress].name = _charityName;
        presentCharities[_charityAddress].link = _link;
        charities.push(_charityName);
        charityAddress.push(_charityAddress);
    }
    
    modifier isWinner() {
        for (uint i =0; i< winers[monthCount].length; i++) {
            require(winers[monthCount][i] == msg.sender);
        }
        _;
    }

    function voteForCharity(bytes8 charity) public isWinner {
        roundCharityVotes[coinRound][charity] += 1;
    }

    function addContract(address _conAddress) public onlyOwner{
        contracts.push(_conAddress);
    }

    modifier isAllowedContract() {
        for (uint i =0; i< contracts.length; i++) {
            require(contracts[i] == msg.sender);
        }
        _;
    }

    function addGovernanceToken(address _gtAdress) public isAllowedContract {
        governanceToken = _gtAdress;
    }
    
    function addToWinners(address _winner) external isAllowedContract {
        winers[monthCount].push(_winner);
    }

    function addFlowDistributor(address addr) public onlyOwner {
        flowDistrubuter = addr;
    }

    function changeReceiverTo(address _charityAddress) private returns (bytes memory) {
        bytes memory payload = abi.encodeWithSignature(
            "changeReceiverAdress(address)",
            _charityAddress
        );
        (bool success, bytes memory returnData) = address(flowDistrubuter).call(payload);
        require(success);
        return returnData;
    }
    

   function predictAsset(
        uint256 _start, 
        uint256 coin, /* integer for the index of the stablecoin in allowedPayments, */
        uint256 _end,
        address[] calldata swapPairs
    ) public allowedToken(allowedPayments[coin]) returns (bytes memory /*, uint[] memory */)
    {
        int256 amount;
        uint256 duration = 300 seconds;
        
        if (getPrice() > roundStartPrice[coinRound]) {
            amount = ((getPrice() - roundStartPrice[coinRound]) * 100) + 5 * 10 ** 18;
        } else {
            amount  = 5 * 10 ** 18;
        }
        require(IERC20(allowedPayments[coin]).allowance(msg.sender, address(this)) >= uint(amount));
        IERC20(allowedPayments[coin]).transferFrom(msg.sender, address(this), uint(amount));
        if (allowedPayments[coin] != Dai) {
            IERC20(allowedPayments[coin]).approve(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff, uint(amount));

            address(SWAPADRESS).call(
                    abi.encodeWithSignature(
                    "swapTokensForExactTokens(uint, uint, address[], address, uint)",
                    uint(amount),//amount out
                    uint(amount),//amount in
                    swapPairs, //pairs geting swaped
                    address(this), 
                    1
                )
            );
        }

        IERC20(Dai).approve(IBA, uint(amount));

        bytes memory payload =abi.encodeWithSignature("deposit(address, uint, address, uint)", Dai, amount, address(this), 0);//should have a protocal referal to use
        (bool success, bytes memory returnData) = address(IBA).call(payload);
        require(success);

        roundAddressBetsPlaced[coinRound][msg.sender].squareStartTime = _start;
        
        roundAddressBetsPlaced[coinRound][msg.sender].squareEndTime 
        = 
        roundAddressBetsPlaced[coinRound][msg.sender].squareStartTime + duration;
        //update all the relevant arrays
        roundPlayerArray[coinRound].push(msg.sender);
        roundStartTimeArray[coinRound].push(_start);
        roundEndTimeArray[coinRound].push(_end);
        //update the total value played
        roundTotalStaked[coinRound] += uint(amount);
        roundWinnings[coinRound] = (roundTotalStaked[coinRound] * 90)/100;
        emit Predicted(msg.sender, _start, _end);

        return (returnData /*, returnValues */);


    }

    function getPrice() public view returns(int256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0xCeE03CF92C7fFC1Bad8EAA572d69a4b61b6D4640);//returns Link/matic Price 
        (,int256 answer,,,) = priceFeed.latestRoundData();
        return int256(answer * 10000000000);
    }

    function getTime() public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0xCeE03CF92C7fFC1Bad8EAA572d69a4b61b6D4640);
        //Matic network
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

     function givePrize(uint256 _round) private {
        require(roundWinningIndex[_round].length != 0);
        if (roundWinningIndex[_round].length == 1) {
    
            IERC20(Dai).transfer(roundPlayerArray[_round][roundWinningIndex[_round][0]], roundWinnings[coinRound]);

        } else {
            for (uint8 i = 0; i < roundWinningIndex[_round].length; i++) {
                require(roundPlayerArray[_round][roundWinningIndex[_round][i]] == msg.sender);
                IERC20(Dai).transfer(
                    roundPlayerArray[_round][roundWinningIndex[_round][i]], 
                    roundWinnings[coinRound]/roundWinningIndex[_round].length
                );
            }
        }
        totalPaid += roundWinnings[coinRound];

    }

    function setTime() private {
        roundWinningTime[coinRound] = getTime();
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
            return (true, /* address(this).call( */ abi.encodePacked(uint256(0)));
        }
        if (roundWinningIndex[coinRound].length != 0) {
            upkeepNeeded = true;
            return (true, abi.encodePacked(uint256(1)));
        }
        if (block.timestamp >= payroundStartTime + 30 days) {
            upkeepNeeded = true;
            return (true, abi.encodePacked(uint256(2)));
        }
        performData = checkData;
        
    }

function performUpkeep(bytes calldata performData) external override {
        uint256 decodedValue = abi.decode(performData, (uint256));
        if(decodedValue == 0){
            setTime();
        } 
        if(decodedValue == 1){
            withdrawRoundFundsFromIba();
        }
        if (decodedValue ==2) {
            payroundStartTime +=30 days;
            withdrawInterest(_aaveToken);
            flowToPaymentDistributer();
            distributeToMembers();
        }
    }

    modifier allowedToken(address _token) {
        for(uint i =0; i < allowedPayments.length; i++) {
            require(allowedPayments[i] == _token);
        }
        _;
    }

    function setwinningCharity() internal{
        uint128 winning_votes = 0;
        for (uint i =0; i < charities.length; i++) {
            if (roundCharityVotes[monthCount][charities[i]] > winning_votes){
                winning_votes == roundCharityVotes[monthCount][charities[i]];
                roundVoteResults[monthCount] = charityAddress[i];
            }
        }
        changeReceiverTo(roundVoteResults[monthCount]);
        //return charities[i];
    }

    //withdraws the total Amount after the moonpice gets hit
    function withdrawRoundFundsFromIba() private returns (bytes memory) {
        bytes memory payload =abi.encodeWithSignature("withdraw(address, uint, address)", Dai, roundWinnings[coinRound], address(this));
        (bool success, bytes memory returnData) = address(IBA).call(payload);
        require(success);
        return returnData;
        
        //Withdraws Funds from the predictions and the interest earned
    }

    function distributeToMembers() private returns (bytes memory) {
        require(monthCount != 0);
        uint256 cashAmount = _acceptedToken.balanceOf(governanceToken);
        bytes memory payload = abi.encodeWithSignature(
            "distribute(uint256)",
            cashAmount
        );
        (bool success, bytes memory returnData) = address(governanceToken).call(payload);
        require(success);
        return returnData;

    }

    function withdrawInterest(address aaveToken) private returns(uint, bytes memory) {
        uint aaveBalance = IERC20(aaveToken).balanceOf(address(this));
        uint interest = aaveBalance - (roundTotalStaked[coinRound] - totalPaid);
        bytes memory payload = abi.encodeWithSignature(
            "withdraw(address, uint, address)",
            Dai,
            interest,
            address(this)
        );
        (bool success, bytes memory returnData) = address(IBA).call(payload);
        require(success);
        ISuperToken(_acceptedToken).upgrade(interest);
        return(interest, returnData);
        //remember to upgrade the dai for flow

    }
    //distributes the Interest Earned on the round to members of the Dao
    function flowToPaymentDistributer(/*uint256 _round, bytes calldata ctx */) private returns(bytes memory newCtx){
        //Flows interest earned from the protocal to the redirectAll contract that handles distribution
        //newCtx = ctx;
            //Flow Winnings
        (newCtx, ) = _host.callAgreementWithContext(
            _cfa,
            abi.encodeWithSelector(
                _cfa.createFlow.selector,
                _acceptedToken,
                flowDistrubuter,//address to the distributer that sends funds to charity and Dao
                (roundInterestEarned[monthCount] / 30 days), //should be the total amount of Interest withdrawnfrom the IBA divided by the number of seconds in the withdrawal interval
                new bytes(0) // placeholder
            ),
            "0x",
            newCtx
        );
        monthCount += 1;
    }
}