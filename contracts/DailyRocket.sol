//SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "../interfaces/DataTypes.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/TransferHelper.sol";

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IHandler.sol";

contract DailyRocket is Ownable, KeeperCompatibleInterface {

    ILendingPoolAddressesProvider private provider = ILendingPoolAddressesProvider(
        address(0x88757f2f99175387aB4C6a4b3067c77A695b0349)
    );  
    ILendingPool private lendingPool = ILendingPool(provider.getLendingPool());

    IHandler private handler;

    uint128 public dayCount;//Kepps track of the days
    
    AggregatorV3Interface private priceFeed;

    string public assetName;  

    mapping(uint256 => mapping(address => uint256[])) public addressBets;

    struct DayInfo {
        int256 closePrice;
        uint256 noOfWinners;
        uint256 totalAmount;
        uint256 totalBets;
        int256 leastDifference;
    }

    mapping(uint256 => DayInfo) public dayAssetInfo;

    mapping(uint256 => uint256) public dayCloseTime; //Closing Time for every asset
    
    address Dai = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;

    uint256 public contractStartTime; //The contract should start at 0000.00 hours

    event Predicted(address indexed _placer, uint256 indexed _betId, int256 _prediction, uint256 _time);

    event SentToIBA(uint256 indexed amount, uint256 indexed day);
    

    struct Prediction {
        address owner;
        int256 prediction;
        uint256 time;
        bool isWinner;
        bool paid;
    }

    //user and their prediction
    mapping(uint128 => mapping(uint256 => Prediction)) public dayBetIdInfo;

    constructor(
        string memory _asset,
        AggregatorV3Interface agg,
        IHandler _handler
        )
    {
        assetName = _asset;
        priceFeed = agg;
        handler = _handler;
        contractStartTime = getTime();
        dayCount = 1;
        dayCloseTime[1] = getTime() + 1 days;
    }


    function setNewClosingPrice() internal {
        dayAssetInfo[dayCount].closePrice = getPrice();
    }

    function getAddressTotoalBets(uint256 day_, address user_) public view returns(uint256) {
        return addressBets[day_][user_].length;
    }


    function predictClosePrice( 
        int _prediction
    ) external
    {   
        require(getTime() <= dayCloseTime[dayCount] + 20 hours);//@dev: After this time, one cannot predict    
        uint256 amount = 10000000000000000000;//the amount we set for the daily close
        uint256 betId = dayAssetInfo[dayCount].totalBets;
        require(IERC20(Dai).allowance(msg.sender, address(this)) >= uint(amount));
        IERC20(Dai).transferFrom(msg.sender, address(this), uint(amount));
        
        dayAssetInfo[dayCount].totalAmount += amount;
        //Updates The prediction mapping
        dayBetIdInfo[dayCount][betId] = Prediction(
            msg.sender,
            _prediction,
            getTime(),
            false,
            false
        );
        addressBets[dayCount][msg.sender].push(betId);
        dayAssetInfo[dayCount].totalBets +=1;
        sendToIba(1 ether);
        emit Predicted(msg.sender, betId, _prediction, block.timestamp);
    }


    function _getVictor() private {
        for (uint8 p = 0; p <= dayAssetInfo[dayCount].totalBets; p++){
            int256 difference_ = dayAssetInfo[dayCount].leastDifference;
            if
            (
                getWinner(
                    dayAssetInfo[dayCount].closePrice,
                    dayBetIdInfo[dayCount][p].prediction,
                    difference_
                ) == true
            ) {
                dayBetIdInfo[dayCount][p].isWinner = true;
                dayAssetInfo[dayCount].noOfWinners +=1;
            }
        }
    }


    function selectWinner() private {
        int256 difference = dayAssetInfo[dayCount].closePrice;
        for (uint8 p = 0; p < dayAssetInfo[dayCount].totalBets; p++) {
            if 
            (
                getDifference(
                    dayAssetInfo[dayCount].closePrice,
                    dayBetIdInfo[dayCount][p].prediction
                ) < difference
            ) {
                difference = getDifference(
                    dayAssetInfo[dayCount].closePrice,
                    dayBetIdInfo[dayCount][p].prediction
                );
            }
        }
        dayAssetInfo[dayCount].leastDifference = difference;
    }


    function getDifference(int256 closePrice, int256 playerPrice) private pure returns(int256) {
        if(closePrice > playerPrice) {
            return closePrice - playerPrice;
        } else {
            return playerPrice - closePrice;
        }
    }

    function getWinner(
        int256 closePrice,
        int256 playerPrice,
        int256 difference
    ) private pure returns(bool) {
        if(closePrice > playerPrice) {
            return (closePrice - difference) == playerPrice;
        } else if (closePrice < playerPrice){
            return (playerPrice - difference) == closePrice;
        }
    }


    function getTime() public view returns(uint){
        (,,,uint answer,) = priceFeed.latestRoundData();
         return uint(answer);
    }


    function getPrice() public view returns(int){
        (,int answer,,,) = priceFeed.latestRoundData();
         return int(answer/100000000);
    }



    function claimWinnings(
        uint128 _day,
        uint256 betId,
        string memory _charity
    ) external {
        //logic to see if the person had a winning prediction
        require(
            dayBetIdInfo[_day][betId].isWinner == true 
            && 
            dayBetIdInfo[_day][betId].paid == false
        );
        uint256 winners = dayAssetInfo[_day].noOfWinners;
        address winner = dayBetIdInfo[_day][betId].owner;
        IERC20(Dai).transfer(
            winner, 
            ((dayAssetInfo[_day].totalAmount) * 90/100)/winners
        );
        dayBetIdInfo[_day][betId].paid = true;
        handler.voteForCharity(_charity);
    }


    function isAwinner(
        uint128 _day,
        uint256 checked
    ) public view returns(bool){
        return dayBetIdInfo[_day][checked].isWinner;
    }


    function checkUpkeep(
        bytes calldata /*checkData*/
    ) external view override returns (
        bool upkeepNeeded, bytes memory performData
    )
    {
        upkeepNeeded = getDay();
        
    }


    function performUpkeep(bytes calldata performData) external override {
        if (getTime() >= dayCloseTime[dayCount]) {
            dayCloseTime[dayCount + 1] = getTime() + 1 days;
            setNewClosingPrice();
            if (dayAssetInfo[dayCount].totalBets != 0) {
                selectWinner();
                _getVictor();
            }
            dayCount+=1;
        }
    }


    //sends non winnings to an interest bearibg account 
    function sendToIba(uint amount) private {
        IERC20(Dai).approve(address(lendingPool), amount);
        lendingPool.deposit(
            Dai,
            uint(amount),
            address(handler),
            0
        );    
        emit SentToIBA(uint(amount), dayCount);
    }

    function getDay() public view returns(bool) {
        return getTime() >= dayCloseTime[dayCount];
    }
}
