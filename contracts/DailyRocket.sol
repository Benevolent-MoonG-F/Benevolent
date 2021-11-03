//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

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
    
    address constant IBA = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    

    uint256 public contractStartTime; //The contract should start at 0000.00 hours

    
    mapping(uint256 => mapping(bytes8 => mapping(IERC20 => uint256))) public dayAssetTokenAmount;
    

    mapping(uint256 => mapping(bytes8 => uint256)) public dayAssetTotalAmoint;


    mapping(uint256 => mapping(bytes8 => uint256)) public dayAssetNoOfWinners;
    

    mapping(uint256 => mapping(bytes8 => uint256)) public dayAssetDaiAmointPerWinner;


    mapping(uint256 => mapping(bytes8 => uint256)) public dayAssetUstAmointPerWinner;
    

    mapping(uint256 => mapping(bytes8 => uint256[])) public dayAssetPrediction;


    mapping(uint256 => mapping(bytes8 => address[])) public dayAssetPredictors;


    event Predicted(address indexed _placer, uint256 _prediction, bytes8 indexed _charity);
    
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
    
    mapping(uint128 => mapping(bytes8 => uint128)) public monthCharityVotes;
    
    mapping(uint128 => bytes8) monthVoteResults;
    
    mapping(uint128 => uint256) public monthCharityAmount;

    mapping(uint128 => mapping(IERC20 => uint256)) monthTokenCharityAmount;


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
    
    function addCharity(bytes8 _charityName, address _charityAddress, bytes32 _link) public onlyOwner{
        presentCharities[_charityAddress].name = _charityName;
        presentCharities[_charityAddress].link = _link;
        charities.push(_charityName);
        charityAddress.push(_charityAddress);
    }

    function predictClosePrice(bytes8 _asset, uint256 _prediction, uint256 _token, bytes8 _charity) public {
        require(getTime() <= dayCloseTime[dayCount -1] + 64800 seconds);
        uint256 amount = 10 * 10**18;//the amount we set for the daily close
        require(AssetIsAccepted(_asset));//confirm the selected is an allowed asset
        require(tokenIsAccepted(AcceptedTokens[_token]), 'Token is currently not allowed.');//checks if the ERC20 token is allowed by the protocal
        // remember to add aprovefunction on ERC20 token
        IERC20(AcceptedTokens[_token]).approve(address(this), amount);
        IERC20(AcceptedTokens[_token]).transferFrom(msg.sender, address(this), amount);//The transfer function on the ERC20 token
        dayAssetTokenAmount[dayCount][_asset][AcceptedTokens[_token]] += amount;
        //Updates The prediction mapping
        dayAssetUserPrediction[dayCount][_asset][msg.sender] = _prediction;
        //adds to the list of predictions
        dayAssetPrediction[dayCount][_asset].push(_prediction);
        //add the sender to the predictors array
        dayAssetPredictors[dayCount][_asset].push(msg.sender);
        voteForCharity(_charity);
        monthCharityAmount[monthCount] += (amount * 7/100);

        emit Predicted(msg.sender, _prediction, _charity);
    }

    function setNumberOfWinners() public {
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
        for (uint i =0; i< AcceptedTokens.length; i++){
            IERC20(AcceptedTokens[i]).transfer(
                msg.sender, (dayAssetTokenAmount[_day][_asset][AcceptedTokens[i]]/dayAssetNoOfWinners[_day][_asset]) * 90/100
            );
        }
    }
    
    function checkUpkeep(bytes calldata /* checkData */) external override returns (bool upkeepNeeded, bytes memory /* performData */) {
        if (dayCloseTime[dayCount] + 86400 seconds == getTime()){
            upkeepNeeded = true;
        }
    }
    
    function performUpkeep(bytes calldata /* performData */) external override {
        setNewClosingPrice();
        setNumberOfWinners();
        dayCount++;
    }
    
    //called inside the predict function
    function voteForCharity(bytes8 charity) internal {
        monthCharityVotes[monthCount][charity] += 1;
    }
    
    
    function setwinningCharity() internal returns(bytes8){
        uint128 winning_votes = 0;
        bytes8 winning_charity;
        for (uint i =0; i < charities.length; i++) {
            if (monthCharityVotes[monthCount][charities[i]] > winning_votes){
                monthVoteResults[monthCount] = charities[i];
            }
        }
        return winning_charity;
    }

    
    function sendToCharity() public onlyOwner {
        
    }
    
    //sends non winnings to an interest bearibg account 
    function sendToIba() public onlyOwner {
        require(getTime() > dayCloseTime[dayCount -1] + 64800 seconds);
        for (uint128 i = 0; i < predictableAssets.length; i++) {
            for (uint p = 0; p < AcceptedTokens.length; p++) {
                IERC20(AcceptedTokens[p]).transfer(IBA, (dayAssetTokenAmount[dayCount][predictableAssets[i]][AcceptedTokens[p]]) * 10/100);
            }
        }
    }
    
    function withdrawCharityFromIba() internal {
        for (uint p = 0; p < AcceptedTokens.length; p++) {
            IERC20(AcceptedTokens[p]).transferFrom(
                IBA,
                address(this),
                (monthTokenCharityAmount[monthCount][AcceptedTokens[p]]) //Hence should be done before the month count gets updated
            );
        }
        
    }

    /*
        Remaining:
            Tracking IBA returns & Protocal money
            Transfrering Protocal Money from IBA
    */
    
    
}


















