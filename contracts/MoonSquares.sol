//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
pragma abicoder v2;

import "../interfaces/TransferHelper.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/DataTypes.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";

import {IERC20} from "../interfaces/IERC20.sol";

import "../interfaces/IRedirect.sol";
import "../interfaces/IGovernanceToken.sol";

import "../interfaces/IHandler.sol";


//make it a super app to allow using superfluid flows and instant distribution
contract MoonSquares is KeeperCompatibleInterface, Ownable {

    string[] public allowedAssets;//All assets that are predicted on the platform
    
    address[] private assetPriceAggregators;

    address[] public contracts;

    mapping(string => address) public assetToAggregator;

    mapping(string => uint256) public coinRound;
    //uint128 public coinRound;

    uint128 public monthCount;

    uint public payroundStartTime;

    uint128 constant payDayDuration = 30 days;

    uint public totalPaid;

    //IUniswapV2Router02 public sushiRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    ILendingPoolAddressesProvider private provider = ILendingPoolAddressesProvider(
        address(0x88757f2f99175387aB4C6a4b3067c77A695b0349)
    ); 
    ILendingPool private lendingPool = ILendingPool(provider.getLendingPool());

    //ISwapRouter public immutable swapRouter;
    //uint24 public constant poolFee = 3000;
    
    IRedirect private flowDistrubuter;
    IGovernanceToken private governanceToken;
    IHandler private handler;

    address private Dai = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
    address private _aaveToken = 0xdCf0aF9e59C002FA3AA091a46196b37530FD48a8;
    address private Daix = 0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09;
    
    mapping (uint256 => uint256) public roundInterestEarned;
//
    mapping(uint256 => mapping(string => RoundInfo)) public roundCoinInfo;
    struct RoundInfo {
        int256 moonPrice;
        uint256 winnings;
        int256 startPrice;
        uint256 totalStaked;
        uint256 startTime;
        uint256 winningTime;
        uint256 totalBets;
        uint256 numberOfWinners;
    }

    uint public totalStaked;
    //sample bet
    //structure of the bet
    struct Bet {
        uint256 timePlaced;//make sure to include this in next deployment
        uint256 squareStartTime;
        uint256 squareEndTime;
        address owner;
        bool isWinner;
        bool paid;
    }
    
    struct Charity {
        bytes8 name;
        bytes32 link; //sends people to the charity's official site
    }

    mapping (address => Charity) public presentCharities;

    bytes8[] charities;
    address[] charityAddress;
    
    mapping(uint128 => mapping(bytes8 => uint128)) public roundCharityVotes;
    
    mapping(uint128 => address) public roundVoteResults;

    mapping (uint256 => mapping( string => mapping (uint256 => Bet))) public roundCoinAddressBetsPlaced;

    mapping (address => uint256) totalAmountPlayed;//shows how much every player has placed

    event Predicted(address indexed _placer, uint256 _start, uint _end);

    event CharityThisMonth(address indexed charityAddress_, bytes8 indexed name_);
    

    constructor() {
        payroundStartTime = block.timestamp;
    }

    modifier isAllowedContract() {
        for (uint i =0; i< contracts.length; i++) {
            require(contracts[i] == msg.sender);
        }
        _;
    }

    function _updateStorage(
        uint _start,
        string memory market
    ) internal {
        uint betId = roundCoinInfo[coinRound[market]][market].totalBets;
        roundCoinAddressBetsPlaced[coinRound[market]][market][betId].timePlaced = getTime();
        roundCoinAddressBetsPlaced[coinRound[market]][market][betId].squareStartTime = _start;
        
        roundCoinAddressBetsPlaced[coinRound[market]][market][betId].squareEndTime  = (_start + 1800 seconds);
        roundCoinAddressBetsPlaced[coinRound[market]][market][betId].owner = msg.sender;
        roundCoinInfo[coinRound[market]][market].totalBets +=1;

    } 
    //predicts an asset
   function predictAsset(
        uint256 _start, 
        string memory market
    ) external
    {   
        uint amount = 10000000000000000000;
        uint duration = 300 seconds;
        require(_start > block.timestamp);
        require(IERC20(Dai).allowance(msg.sender, address(this)) >= amount);
        IERC20(Dai).transferFrom(msg.sender, address(this), amount);
        //update the total value played
        roundCoinInfo[coinRound[market]][market].totalStaked += amount;
        roundCoinInfo[coinRound[market]][market].winnings += 9000000000000000;
        totalStaked += amount;
        aaveDeposit(amount);
        _updateStorage(_start, market);
        emit Predicted(msg.sender, _start, (_start + duration));
    }



    function aaveDeposit(uint amount) internal {
        IERC20(Dai).approve(address(lendingPool), amount);
        lendingPool.deposit(
            Dai,
            amount,
            address(this),
            0
        );
    }

    //gets the price of the asset denoted by market
    function getPrice(string memory market) public view returns(int256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(assetToAggregator[market]); 
        (,int256 answer,,,) = priceFeed.latestRoundData();
        return int256(answer/100000000);
    }

    //gets the current time
    function getTime() public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x6135b13325bfC4B00278B4abC5e20bbce2D6580e);
        //Matic network
        (,,,uint256 answer,) = priceFeed.latestRoundData();
         return uint256(answer);
    }

    //it 
    function _checkIndexes(string memory market, uint p) internal view returns(bool){
        if (
            roundCoinAddressBetsPlaced[coinRound[market]][market][p].squareStartTime >= roundCoinInfo[coinRound[market]][market].winningTime
            &&
            roundCoinAddressBetsPlaced[coinRound[market]][market][p].squareEndTime <= roundCoinInfo[coinRound[market]][market].winningTime
        ) {
            return true;
        } else {
            return false;
        }
    }
    function setWinningBets(string memory market) internal {

        for (uint256 p =0; p <= roundCoinInfo[coinRound[market]][market].totalBets; p++) {
            if (_checkIndexes(market, p) == true){
                roundCoinAddressBetsPlaced[coinRound[market]][market][p].isWinner = true;
                roundCoinInfo[coinRound[market]][market].numberOfWinners += 1;
            }
        }
    }

    function isAwiner(
        uint256 _round,
        string memory market,
        uint256 checkedId
    )public view returns(bool) {
        return roundCoinAddressBetsPlaced[coinRound[market]][market][checkedId].isWinner;

    }
    //should use superflid's flow if its just one user & instant distribution if there are several winners

     function takePrize(
         uint round,
         string memory market,
         uint256 betId,
         bytes8 charity
    ) external {
        require(roundCoinInfo[round][market].numberOfWinners != 0);
        require(
            roundCoinAddressBetsPlaced[round][market][betId].isWinner == true
            &&
            roundCoinAddressBetsPlaced[round][market][betId].paid == false
        );
        uint paids = roundCoinInfo[coinRound[market]][market].winnings/roundCoinInfo[coinRound[market]][market].numberOfWinners;
        IERC20(Dai).transfer(
            roundCoinAddressBetsPlaced[round][market][betId].owner,
            (roundCoinInfo[coinRound[market]][market].winnings/paids)
        );
        totalPaid += paids;
        roundCoinAddressBetsPlaced[round][market][betId].paid = true;
        roundCharityVotes[monthCount][charity] += 1;
    }

    function setTime(string memory market) public {
        roundCoinInfo[coinRound[market]][market].winningTime = getTime();
        setWinningBets(market);
        withdrawRoundFundsFromIba(market);
    }

    function checkUpkeep(
        bytes calldata /*checkData*/
    ) external view override returns (
        bool upkeepNeeded, bytes memory performData
    ) {
        for (uint256 p = 0; p < allowedAssets.length; p++) {
        
            if (
                getPrice(allowedAssets[p])
                ==
                roundCoinInfo[coinRound[allowedAssets[p]]][allowedAssets[p]].moonPrice
            ) {
                upkeepNeeded = true;
                performData = abi.encodePacked(uint256(p));
                return (true, performData);
            }
        }
        if (block.timestamp >= payroundStartTime + 30 days) {
            upkeepNeeded = true;
            performData = abi.encodePacked(uint256(1000));
            return (true, performData);
        }
        
    }

    function performUpkeep(bytes calldata performData) external override {
        uint256 decodedValue = abi.decode(performData, (uint256));
        if(decodedValue < allowedAssets.length){
            setTime(allowedAssets[decodedValue]);
        }
        if (decodedValue ==1000) {
            payroundStartTime +=30 days;
            withdrawInterest(_aaveToken);
            flowToPaymentDistributer();
            distributeToMembers();
        }
    }

    function setwinningCharity() public {
        uint128 winning_votes = 0;
        uint index = 0;
        for (uint i =0; i < charities.length; i++) {
            if (roundCharityVotes[monthCount][charities[i]] > winning_votes){
                winning_votes == roundCharityVotes[monthCount][charities[i]];
            }
            if (roundCharityVotes[monthCount][charities[i]] == winning_votes) {
                roundVoteResults[monthCount] = charityAddress[i];
                index = i;
            }
        }
        flowDistrubuter.changeReceiverAdress(roundVoteResults[monthCount]);
        emit CharityThisMonth(roundVoteResults[monthCount], charities[index]);
    }

    //withdraws the total Amount after the moonpice gets hit
    function withdrawRoundFundsFromIba(string memory market) private {
        require(roundCoinInfo[coinRound[market]][market].numberOfWinners != 0);
        lendingPool.withdraw(
            Dai,
            roundCoinInfo[coinRound[market]][market].winnings,
            address(this)
        );
        
        //Withdraws Funds from the predictions
    }

    function distributeToMembers() private {
        require(monthCount != 0);
        uint256 cashAmount = IERC20(Daix).balanceOf(address(governanceToken));
        governanceToken.distribute(
            cashAmount
        );
    }

    function withdrawInterest(address aaveToken) private returns(uint) {
        uint aaveBalance = IERC20(aaveToken).balanceOf(address(this));
        uint interest = aaveBalance - (totalStaked - totalPaid);
        lendingPool.withdraw(
            Dai,
            interest,
            address(handler)
        );
        handler.upgradeToken(interest);
        roundInterestEarned[monthCount] = interest;
        return(interest);
        //remember to upgrade the dai for flow
        //verify which token is getting upgraded

    }
    //distributes the Interest Earned on the round to members of the Dao
    function flowToPaymentDistributer() private {
        //Flows interest earned from the protocal to the redirectAll contract that handles distribution
            //Flow Winnings
        int256 toInt = int256(roundInterestEarned[monthCount]);
        handler.createFlow(int96(toInt / 30 days));
        monthCount += 1;
    }

    function addAssetsAndAggregators(
        string memory _asset,
        address _aggregator
    ) external onlyOwner {
        require(allowedAssets.length < 100);
        assetToAggregator[_asset] = _aggregator;
        allowedAssets.push(_asset);
        assetPriceAggregators.push(_aggregator);
    }

    function addCharity(
        bytes8 _charityName,
        address _charityAddress,
        bytes32 _link
    ) external onlyOwner {
        presentCharities[_charityAddress].name = _charityName;
        presentCharities[_charityAddress].link = _link;
        charities.push(_charityName);
        charityAddress.push(_charityAddress);
    }

    function setMoonPrice(
        int price,
        string memory market
    ) external onlyOwner {
        roundCoinInfo[coinRound[market]][market] = RoundInfo(
            price,
            0,
            getPrice(market),
            0,
            getTime(),
            0,
            0,
            0
        );

    }
    //puts the 10% from daily rocket into account
    function acountForDRfnds(uint amount) external isAllowedContract {
        totalStaked += amount;
    }
    function voteForCharity(bytes8 charity) external isAllowedContract {
        roundCharityVotes[monthCount][charity] += 1;
    }

    //adds contracts that call core funtions
    function addContract(address _conAddress) external onlyOwner{
        contracts.push(_conAddress);
    }

    function addGovernanceToken(IGovernanceToken _gtAdress) external isAllowedContract {
        governanceToken = _gtAdress;
    }
    //adds the flow distributor
    function addFlowDistributor(IRedirect addr) external onlyOwner {
        flowDistrubuter = addr;
    }
}