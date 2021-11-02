//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';


contract MoonSquares is KeeperCompatibleInterface, Ownable, ReentrancyGuard {


    IERC20[] public allowedPayments;//list of all accepted stablecoins for placing a prediction

    uint128 public coinRound;


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
   function predictAsset(uint256 _start, uint256 coin /* integer for the index of the stablecoin in allowedPayments*/, uint256 _end) external nonReentrant {
        uint256 amount = 5 * 10 ** 18;
        uint256 duration = 300 seconds;
        //logic for the amount.

        //transfer stablecoin
        allowedPayments[coin].approve(address(this), amount);
        allowedPayments[coin].transferFrom(msg.sender, address(this), amount);

        //Dai.transferFrom(msg.sender, address(this), amount);
        //update the betsPlaced mapping
        roundAddressBetsPlaced[coinRound][msg.sender].squareStartTime = _start;
        roundAddressBetsPlaced[coinRound][msg.sender].squareEndTime = roundAddressBetsPlaced[coinRound][msg.sender].squareStartTime + duration;
        //update all the relevant arrays
        roundPlayerArray[coinRound].push(msg.sender);
        roundStartTimeArray[coinRound].push(_start);
        roundEndTimeArray[coinRound].push(_end);
        //update the total value played
        roundTotalStaked[coinRound] += amount;
        roundCharityContributions[coinRound] = (roundTotalStaked[coinRound] * 7)/100;
        roundWinnings[coinRound] = (roundTotalStaked[coinRound] * 90)/100;
        roundContractContribution[coinRound] = (roundTotalStaked[coinRound] * 3)/100;

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

     function claimPrize(uint256 _round) external {
        for (uint8 i = 0; i < roundWinningIndex[_round].length; i++) {
            require(roundPlayerArray[_round][roundWinningIndex[_round][i]] == msg.sender);
            //Transfer logic for winning
        }
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external override returns (
        bool upkeepNeeded, bytes memory /* performData */
    ) {
        if (getPrice() == roundMoonPrice[coinRound]) {
            upkeepNeeded = true;
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
            }
        }
        return false; 
    }

    function setwinningCharity() internal returns(bytes8){
        uint128 winning_votes = 0;
        for (uint i =0; i < charities.length; i++) {
            if (roundCharityVotes[coinRound][charities[i]] > winning_votes){
                roundVoteResults[coinRound] = charities[i];
            }
        }
        //return charities[i];
    }

    //sends all thefunds to an interest bearing acount
    function sendToIba() internal {

    }

    //withdraws the winnings and the charity funds after the moonpice gets hit
    function withdrawFromIba() internal {

    }

    //sends the rounds's charity donations to the winning charity
    function sendToWinningCharity() internal {

    }

}