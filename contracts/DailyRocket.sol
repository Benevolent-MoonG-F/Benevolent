//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';



contract DailyRocket is Ownable, KeeperCompatibleInterface {

    //preferably should use the http get to get the actual close price of an asset rather than aggregator
    //to confirm during testing phase

    uint128 dayCount;//Kepps track of the days
    
    uint128 monthCount;

    bytes8[] predictableAssets;//all assets that a user can predict
    address[] assetPriceAggregators;

    mapping(uint256 => mapping(bytes8 => uint256)) dayAssetClosePrice; //Closing Price per asset 

    mapping(uint256 => uint256) dayCloseTime; //Closing Time per asset
    
    address constant IBA = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;//aavelending pool
    IERC20 Dai;
    address QuickSwap;
    address moonSquare;
    

    uint256 public contractStartTime; //The contract should start at 0000.00 hours


    mapping(uint256 => mapping(bytes8 => uint256)) public dayAssetTotalAmount;


    mapping(uint256 => mapping(bytes8 => uint256)) public dayAssetNoOfWinners;
    

    mapping(uint256 => mapping(bytes8 => uint256[])) public dayAssetPrediction;


    mapping(uint256 => mapping(bytes8 => address[])) public dayAssetPredictors;


    event Predicted(address indexed _placer, uint256 _prediction);
    
    struct Charity {
        bytes8 name;
        bytes32 link; //sends people to the charity's official site
    }
    
    mapping (address => Charity) public presentCharities;


    IERC20[] public AcceptedTokens;

    mapping(uint128 => mapping(bytes8 => address[])) public dailyAssetWinners;

    //user and their prediction
    mapping(uint128 => mapping(bytes8 => mapping(address => uint256))) public dayAssetUserPrediction;
    
    bytes8[] charities;
    address[] charityAddress;


    mapping (uint128 => uint256) monthInterestEarned;


    constructor(IERC20 _dai, IERC20 _ust){
        AcceptedTokens.push(_dai);
        AcceptedTokens.push(_ust);
        contractStartTime = block.timestamp;
        dayCount = 1;
        dayCloseTime[dayCount] = contractStartTime + 86400 seconds;//adds a day to the start time. to change to an input later.
    }//instantiate the token addresses upon deployment


    function setNewClosingPrice() internal {
        for (uint256 i = 0; i < assetPriceAggregators.length; i++){
            dayAssetClosePrice[dayCount][predictableAssets[i]] = getPrice(i);
        }
    }
    
    function addAssetAndAgg(bytes8 _asset, address _aggregator) public onlyOwner {
        predictableAssets.push(_asset);
        assetPriceAggregators.push(_aggregator);
    }

    function predictClosePrice(bytes8 _asset, uint256 _prediction, uint256 _token, /*bytes8 _charity,*/ address[] calldata swapPairs) public {
        require(getTime() <= dayCloseTime[dayCount -1] + 64800 seconds);//After this time, one cannot
        uint256 amount = 10 * 10**18;//the amount we set for the daily close
        require(AssetIsAccepted(_asset));//confirm the selected is an allowed asset
        require(tokenIsAccepted(AcceptedTokens[_token]), 'Token is currently not allowed.');//checks if the ERC20 token is allowed by the protocal
        // remember to add aprovefunction on ERC20 token
        IERC20(AcceptedTokens[_token]).approve(address(this), amount);
        if (AcceptedTokens[_token] != Dai) {
            IERC20(AcceptedTokens[_token]).transferFrom(msg.sender, address(this), amount);//The transfer function on the ERC20 token
            IERC20(AcceptedTokens[_token]).approve(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff, amount);
            address(QuickSwap).call(
                abi.encodeWithSignature(
                    "swapTokensForExactTokens(uint, uint, address[], address, uint)",
                    amount,//amount out
                    amount,//amount in
                    swapPairs, //pairs geting swaped
                    address(this), 
                1
                )
            );

        } else {
            IERC20(Dai).transferFrom(msg.sender, address(this), amount);//The transfer function on the ERC20 token
        }


        //IERC20(Dai).approve(address(this), amount);

        dayAssetTotalAmount[dayCount][_asset] += amount;
        //Updates The prediction mapping
        dayAssetUserPrediction[dayCount][_asset][msg.sender] = _prediction;
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
                require(dayAssetPrediction[day][predictableAssets[i]][p] == dayAssetClosePrice[day][predictableAssets[i]]);
                dailyAssetWinners[day][predictableAssets[i]].push(dayAssetPredictors[day][predictableAssets[i]][p]);
                dayAssetNoOfWinners[day][predictableAssets[i]] +=1;
                bytes memory payload =abi.encodeWithSignature("addToWinners(address)", dayAssetPredictors[day][predictableAssets[i]][p]);
                (bool success, bytes memory returnData) = address(IBA).call(payload);
                require(success);
                //return returnData;
            }
        }
    }


    function getTime() public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
        //kovan network
        (,,,uint256 answer,) = priceFeed.latestRoundData();
         return uint256(answer * 10000000000);
    }

    function getPrice(uint256 _aggindex) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(assetPriceAggregators[_aggindex]);
        //kovan network
        (,int256 answer,,,) = priceFeed.latestRoundData();
         return uint256(answer * 10000000000);
    }

    function tokenIsAccepted(IERC20 _token) public view returns (bool) {
        for(uint i =0; i < AcceptedTokens.length; i++) {
            if(AcceptedTokens[i] == _token){
                return true;
            }
        }
        return false; 
    }

    function AssetIsAccepted(bytes8 _asset) public view returns (bool) {
        for(uint i =0; i < predictableAssets.length; i++) {
            if(predictableAssets[i] == _asset) {
                return true;
            }
        }
        return false;
    }

    function claimWinnings(uint128 _day, bytes8 _asset) public {
        //logic to see if the person had a winning prediction
        require(dayAssetUserPrediction[_day][_asset][msg.sender] == dayAssetClosePrice[_day][_asset]);
        IERC20(Dai).transfer(
            msg.sender, (dayAssetTotalAmount[_day][_asset]) * 90/100
        );
        //then they vote for the chaity
        /*
        bytes memory payload =abi.encodeWithSignature("voteForCharity(bytes8)", _charity);
        (bool success, bytes memory returnData) = address(IBA).call(payload);
        require(success);
        return returnData;
        */
        
    }
    
    function checkUpkeep(bytes calldata checkData) external override returns (bool upkeepNeeded, bytes memory performData) {
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
    function sendToIba() private onlyOwner returns (bytes memory) {
        require(getTime() > dayCloseTime[dayCount -1] + 64800 seconds);
        for (uint128 i = 0; i < predictableAssets.length; i++) {
            for (uint p = 0; p < AcceptedTokens.length; p++) {
                bytes memory payload =abi.encodeWithSignature("deposit(address, uint, address, uint)", Dai, ((dayAssetTotalAmount[dayCount][predictableAssets[i]]) * 10/100), moonSquare, 0);
                (bool success, bytes memory returnData) = address(IBA).call(payload);
                require(success);
                //IERC20(AcceptedTokens[p]).transfer(IBA, (dayAssetTokenAmount[dayCount][predictableAssets[i]][AcceptedTokens[p]]) * 10/100);
                return returnData;
            }
        }
    }

    
}