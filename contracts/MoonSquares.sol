//SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;
pragma abicoder v2;

import "../interfaces/TransferHelper.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/DataTypes.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";

import {IERC20} from "../interfaces/IERC20.sol";

import "../interfaces/IRedirect.sol";

import "../interfaces/IHandler.sol";


//make it a super app to allow using superfluid flows and instant distribution
contract MoonSquares is KeeperCompatibleInterface, Ownable {

    string public assetName;
    uint256 public coinRound;

    uint public totalPaid;

    //IUniswapV2Router02 public sushiRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    ILendingPoolAddressesProvider private provider = ILendingPoolAddressesProvider(
        address(0x178113104fEcbcD7fF8669a0150721e231F0FD4B)
    ); 
    ILendingPool private lendingPool = ILendingPool(provider.getLendingPool());

    //ISwapRouter public immutable swapRouter;
    //uint24 public constant poolFee = 3000;
    IHandler public handler;
    AggregatorV3Interface private priceFeed;

    address private Dai = 0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F;
    
    mapping(uint256 => RoundInfo) public roundInfo;
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

    mapping (uint256 => mapping (uint256 => Bet)) public roundIdBetInfo;

    mapping (uint256 => mapping (address => uint256[])) public roundAddressBetIds;

    event Predicted(uint256 indexed _betId, address sender, uint256 _start);
    

    constructor(
        string memory _asset,
        AggregatorV3Interface feed_,
        IHandler handler_
    ) {
        assetName = _asset;
        priceFeed = feed_;
        handler = handler_;
        coinRound = 1;
        roundInfo[0].winningTime = block.timestamp;
    }

    function _updateStorage(
        uint _start
    ) internal {
        uint betId = roundInfo[coinRound].totalBets;
        roundIdBetInfo[coinRound][betId] = Bet(
            block.timestamp,
            _start,
            (_start + 300 seconds),
            msg.sender,
            false,
            false
        );
        roundAddressBetIds[coinRound][msg.sender].push(betId);
    } 
    //predicts an asset

   function predictAsset(
        uint256 _start
    ) external
    {   
        uint amount = 10 ether;
        require(roundInfo[coinRound].winningTime == 0);
        require(_start > block.timestamp);
        require(IERC20(Dai).allowance(msg.sender, address(this)) >= amount);
        IERC20(Dai).transferFrom(msg.sender, address(this), amount);
        //update the total value played
        roundInfo[coinRound].totalStaked += amount;
        roundInfo[coinRound].winnings += 9000000000000000000;
        totalStaked += amount;
        aaveDeposit(amount);
        handler.acountForDRfnds();
        _updateStorage(_start);
        emit Predicted(roundInfo[coinRound].totalBets, msg.sender, _start);
        roundInfo[coinRound].totalBets +=1;
    }


    function aaveDeposit(uint amount) private {
        IERC20(Dai).approve(address(lendingPool), amount);
        lendingPool.deposit(
            Dai,
            amount,
            address(handler),
            0
        );
    }

    //it 
    function _checkIndexes( uint betId) internal view returns(bool){
        if (
            roundIdBetInfo[coinRound][betId].squareStartTime >= roundInfo[coinRound].winningTime
            &&
            roundIdBetInfo[coinRound][betId].squareEndTime <= roundInfo[coinRound].winningTime
        ) {
            return true;
        } else {
            return false;
        }
    }
    function setWinningBets() internal {
        uint256 total = roundInfo[coinRound].totalBets;
        for (uint256 p =0; p <= total;) {
            if (_checkIndexes(p) == true){
                roundIdBetInfo[coinRound][p].isWinner = true;
                roundInfo[coinRound].numberOfWinners += 1;
            }
            unchecked {
                p++;
            }
        }
    }

    function isAwiner(
        uint256 _round,
        uint256 checkedId
    )public view returns(bool) {
        return roundIdBetInfo[coinRound][checkedId].isWinner;

    }

    function setTime() private {
        roundInfo[coinRound].winningTime = getTime();
        if (roundInfo[coinRound].totalBets != 0){
            setWinningBets();
            withdrawRoundFundsFromIba();
        }
        coinRound++;
    }

    function checkUpkeep(
        bytes calldata /*checkData*/
    ) external view override returns (
        bool upkeepNeeded, bytes memory performData
    ) {
        upkeepNeeded = (getPrice() == roundInfo[coinRound].moonPrice);
    }

    function performUpkeep(bytes calldata performData) external override {
        setTime();
    }

     function takePrize(
         uint round,
         uint256 betId,
         string memory charity
    ) external {
        require(roundInfo[round].numberOfWinners != 0);
        require(
            roundIdBetInfo[round][betId].isWinner == true
            &&
            roundIdBetInfo[round][betId].paid == false
        );
        uint paids = roundInfo[round].winnings/roundInfo[round].numberOfWinners;
        IERC20(Dai).transfer(
            roundIdBetInfo[round][betId].owner,
            (paids)
        );
        totalPaid += paids;
        roundIdBetInfo[round][betId].paid = true;
        handler.voteForCharity(charity);
    }
    //withdraws the total Amount after the moonpice gets hit
    function withdrawRoundFundsFromIba() private {
        require(roundInfo[coinRound].numberOfWinners != 0);
        handler.withdrawRoundFunds(roundInfo[coinRound].winnings);
        //Withdraws Funds from aave for the prediction
    }

    function setMoonPrice(
        int price
    ) external onlyOwner {
        require(roundInfo[coinRound -1].winningTime != 0);
        roundInfo[coinRound] = RoundInfo(
            price,
            0,
            getPrice(),
            0,
            getTime(),
            0,
            0,
            0
        );

    }

    //gets the price of the asset denoted by market
    function getPrice() public view returns(int256){
        (,int256 answer,,,) = priceFeed.latestRoundData();
        return int256(answer/100000000);
    }

    //gets the current time
    function getTime() public view returns(uint256){
        //Matic network
        //(,,,uint256 answer,) = priceFeed.latestRoundData();
         return block.timestamp;
    }

    function getRoundbets(uint256 round_, address sender_) public view returns(uint256) {
        return roundAddressBetIds[round_][sender_].length;
    }

}