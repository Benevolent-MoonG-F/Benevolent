//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/DataTypes.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/TransferHelper.sol";
import "../interfaces/IMoonSquares.sol";

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract DailyRocket is Ownable, KeeperCompatibleInterface {

    ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
        address(0x88757f2f99175387aB4C6a4b3067c77A695b0349)
    );  
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    
    IMoonSquares public moonSquare;

    uint128 public dayCount;//Kepps track of the days

    string[] public predictableAssets;//all assets that a user can predict
    address[] assetPriceAggregators;

    mapping(string => bool) public activeAsset;

    struct DayInfo {
        int256 closePrice;
        uint256 noOfPlayers;
        uint256 noOfWinners;
        uint256 totalAmount;
    }

    mapping(uint => mapping(string => DayInfo)) public dayAssetInfo;

    mapping(uint256 => uint256) dayCloseTime; //Closing Time for every asset
    
    address Dai = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;

    uint256 public contractStartTime; //The contract should start at 0000.00 hours
    
    mapping(uint256 => mapping(string => int256[])) public dayAssetPrediction;

    mapping(uint256 => mapping(string => address[])) public dayAssetPredictors;

    event Predicted(address indexed _placer, int256 _prediction);

    event SentToIBA(uint256 indexed amount, uint256 indexed day);
    
    struct Charity {
        bytes8 name;
        bytes32 link; //sends people to the charity's official site
    }
    struct Prediction {
        int256 prediction;
        uint256 time;
        bool isWinner;
    }
    
    mapping (address => Charity) public presentCharities;

    mapping(uint128 => mapping(string => address[])) public dailyAssetWinners;

    //user and their prediction
    mapping(uint128 => mapping(string => mapping(address => Prediction))) public dayAssetUserPrediction;

    constructor(
        //address _dai,
        IMoonSquares _moonsqr
        )
    {
        //AcceptedTokens.push(_dai);
        moonSquare = _moonsqr;
        contractStartTime = block.timestamp;
        dayCount = 1;
        dayCloseTime[dayCount] = contractStartTime + 86400 seconds;//adds a day to the start time. to change to an input later.
    }//instantiate the token addresses upon deployment


    function setNewClosingPrice() internal {
        for (uint256 i = 0; i < assetPriceAggregators.length; i++){
            dayAssetInfo[dayCount][predictableAssets[i]].closePrice = getPrice(i);
        }
    }
    
    function addAssetAndAgg(string memory _asset, address _aggregator) public onlyOwner {
        predictableAssets.push(_asset);
        assetPriceAggregators.push(_aggregator);
        activeAsset[_asset] = true;
    }

    function predictClosePrice(
        string memory _asset, 
        int _prediction
    ) public
    {   
        require(activeAsset[_asset] == true);
        if (dayCount > 1) {
            require(getTime() <= dayCloseTime[dayCount -1] + 64800 seconds);//After this time, one cannot
        }
        uint256 amount = 10000000000000000000;//the amount we set for the daily close
    
        require(IERC20(Dai).allowance(msg.sender, address(this)) >= uint(amount));
        IERC20(Dai).transferFrom(msg.sender, address(this), uint(amount));
        
        dayAssetInfo[dayCount][_asset].totalAmount += amount;
        //Updates The prediction mapping
        dayAssetUserPrediction[dayCount][_asset][msg.sender] = Prediction(
            _prediction,
            getTime(),
            false
        );
        //adds to the list of predictions
        dayAssetPrediction[dayCount][_asset].push(_prediction);
        //add the sender to the predictors array
        dayAssetPredictors[dayCount][_asset].push(msg.sender);

        emit Predicted(msg.sender, _prediction);
    }

    function setNumberOfWinners() private {
        uint128 day = dayCount;
        for (uint8 i = 0; i < predictableAssets.length; i++) {
            require(
                dayAssetPrediction[day][predictableAssets[i]].length
                ==
                dayAssetPredictors[day][predictableAssets[i]].length
            );
            for (uint8 p = 0; p < dayAssetPrediction[day][predictableAssets[i]].length; p++) {
                require(
                    dayAssetPrediction[day][predictableAssets[i]][p]
                    ==
                    dayAssetInfo[day][predictableAssets[i]].closePrice
                );
                dailyAssetWinners[day][predictableAssets[i]].push(dayAssetPredictors[day][predictableAssets[i]][p]);
                dayAssetInfo[day][predictableAssets[i]].noOfWinners +=1;

                moonSquare.addToWinners(dayAssetPredictors[day][predictableAssets[i]][p]);
            }
        }
    }


    function getTime() public view returns(uint){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x6135b13325bfC4B00278B4abC5e20bbce2D6580e);
        (,,,uint answer,) = priceFeed.latestRoundData();
         return uint(answer);
    }

    function getPrice(uint256 _aggindex) public view returns(int){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(assetPriceAggregators[_aggindex]);
        (,int answer,,,) = priceFeed.latestRoundData();
         return int(answer);
    }

    function claimWinnings(uint128 _day, string memory _asset) public {
        //logic to see if the person had a winning prediction
        require(dayAssetUserPrediction[_day][_asset][msg.sender].prediction == dayAssetInfo[_day][_asset].closePrice);
        uint256 winners = dayAssetInfo[_day][_asset].noOfWinners;
        dayAssetUserPrediction[_day][_asset][msg.sender].isWinner = true;
        IERC20(Dai).transfer(
            msg.sender, 
            ((dayAssetInfo[_day][_asset].totalAmount) * 90/100)/winners
        );
        
    }

    function isAwinner(
        uint128 _day,
        string memory _asset,
        address checked
    ) public view returns(bool){
        if(dayAssetInfo[_day][_asset].closePrice == 0) {
            return false;
        }else {
            require(
                dayAssetUserPrediction[_day][_asset][checked].prediction
                ==
                dayAssetInfo[_day][_asset].closePrice
            );
            return true;
        }
    }
    
    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        if (dayCloseTime[dayCount] + 86400 seconds == getTime()){
            upkeepNeeded = true;
            return (true, abi.encodePacked(uint256(0)));
        }
        if (getTime() > dayCloseTime[dayCount -1] + 64800 seconds) {
            upkeepNeeded = true;
            return (true, abi.encodePacked(uint(1)));
        }
        performData = checkData;
        
    }
    
    function performUpkeep(bytes calldata performData) external override {
         uint256 decodedValue = abi.decode(performData, (uint256));
        if (decodedValue == 0) {
            setNewClosingPrice();
            setNumberOfWinners();
            dayCount++;
        }
        if (decodedValue == 1) {
            sendToIba();
        }
    }
    
    //sends non winnings to an interest bearibg account 
    function sendToIba() private {
        require(getTime() > dayCloseTime[dayCount -1] + 64800 seconds);
        for (uint128 i = 0; i < predictableAssets.length; i++) {
            uint amount = ((dayAssetInfo[dayCount][predictableAssets[i]].totalAmount) * 10/100);
            IERC20(Dai).approve(address(lendingPool), amount);
            lendingPool.deposit(
                Dai,
                uint(amount),
                address(moonSquare),
                0
            );
            emit SentToIBA(uint(amount), dayCount);
        }
    }    
}