//SPDX-License-Identifier: MIT

interface IMoonSquares {

  function addToWinners(address _winner) external;

}

pragma solidity ^0.8.0;

import "../interfaces/DataTypes.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/TransferHelper.sol";
import "../interfaces/ISwapRouter.sol";

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract DailyRocket is Ownable, KeeperCompatibleInterface {

    //preferably should use the http get to get the actual close price of an asset rather than aggregator
    //to confirm during testing phase


    IUniswapV2Router01 public sushiRouter = IUniswapV2Router01(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
        address(0x178113104fEcbcD7fF8669a0150721e231F0FD4B)
    ); // mainnet address, for other addresses: https://docs.aave.com/developers/deployed-contracts/deployed-contract-instances 
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    
    IMoonSquares moonSquare = IMoonSquares(0xF033ff1c065704E6664d4581884578A9FcE44b69);
    ISwapRouter public immutable swapRouter;
    uint24 public constant poolFee = 3000;

    uint128 dayCount;//Kepps track of the days

    uint[] predictableAssets;//all assets that a user can predict
    address[] assetPriceAggregators;

    mapping(uint256 => mapping(uint => int256)) dayAssetClosePrice; //Closing Price per asset 

    mapping(uint256 => uint256) dayCloseTime; //Closing Time per asset
    
    //address constant IBA = 0x9198F13B08E299d85E096929fA9781A1E3d5d827;//aavelending pool
    address Dai = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
    //address QuickSwap = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

    uint256 public contractStartTime; //The contract should start at 0000.00 hours

    mapping(uint256 => mapping(uint => uint256)) public dayAssetTotalAmount;

    mapping(uint256 => mapping(uint => uint256)) public dayAssetNoOfWinners;
    
    mapping(uint256 => mapping(uint => int256[])) public dayAssetPrediction;

    mapping(uint256 => mapping(uint => address[])) public dayAssetPredictors;

    event Predicted(address indexed _placer, int256 _prediction);
    
    struct Charity {
        bytes8 name;
        bytes32 link; //sends people to the charity's official site
    }
    
    mapping (address => Charity) public presentCharities;

    address[] public AcceptedTokens;

    mapping(uint128 => mapping(uint => address[])) public dailyAssetWinners;

    //user and their prediction
    mapping(uint128 => mapping(uint => mapping(address => int256))) public dayAssetUserPrediction;

    constructor(
        address _dai,
        ISwapRouter _swapRouter
        )
    {
        AcceptedTokens.push(_dai);
        swapRouter = _swapRouter;
        contractStartTime = block.timestamp;
        dayCount = 1;
        dayCloseTime[dayCount] = contractStartTime + 86400 seconds;//adds a day to the start time. to change to an input later.
    }//instantiate the token addresses upon deployment


    function setNewClosingPrice() internal {
        for (uint256 i = 0; i < assetPriceAggregators.length; i++){
            dayAssetClosePrice[dayCount][predictableAssets[i]] = getPrice(i);
        }
    }

    function addPaymentToken(address _address) public onlyOwner {
        AcceptedTokens.push(_address);
    }
    
    function addAssetAndAgg(uint _asset, address _aggregator) public onlyOwner {
        predictableAssets.push(_asset);
        assetPriceAggregators.push(_aggregator);
    }

    function predictClosePrice(
        uint _asset, 
        int _prediction,
        address token
    ) public allowedAsset(_asset)
    {   
        if (dayCount > 1) {
            require(getTime() <= dayCloseTime[dayCount -1] + 64800 seconds);//After this time, one cannot
        }
        uint256 amount = 10000000000000000000;//the amount we set for the daily close
        if (token != Dai) {
            require(IERC20(Dai).allowance(msg.sender, address(this)) >= uint(amount));
            //IERC20(token).transferFrom(msg.sender, address(this), uint(amount));
            TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);

            // Approve the router to spend the specifed `amountInMaximum` of DAI.
            // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
            TransferHelper.safeApprove(token, address(swapRouter), amount);
            uint amountInMaximum = 15000000000000000000;
            ISwapRouter.ExactOutputSingleParams memory params =
                ISwapRouter.ExactOutputSingleParams({
                    tokenIn: token,
                    tokenOut: Dai,
                    fee: poolFee,
                    recipient: msg.sender,
                    deadline: block.timestamp,
                    amountOut: amount,
                    amountInMaximum: amountInMaximum,
                    sqrtPriceLimitX96: 0
                });

            // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
            uint amountIn = swapRouter.exactOutputSingle(params);

            // For exact output swaps, the amountInMaximum may not have all been spent.
            // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
            if (amountIn < amountInMaximum) {
                TransferHelper.safeApprove(Dai, address(swapRouter), 0);
                TransferHelper.safeTransfer(Dai, msg.sender, amountInMaximum - amountIn);
            }

            /*
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = Dai;
            uint amountOut = 10000000000000000000;
            uint amountIn = sushiRouter.getAmountsIn(
                amountOut,
                path
            )[0];
        
            IERC20(token).approve(address(sushiRouter), amountIn);

            sushiRouter.swapExactTokensForTokens(
                amountIn, 
                amountOut,
                path, 
                msg.sender, 
                block.timestamp + 60
            );
            */
        } else {
            require(IERC20(Dai).allowance(msg.sender, address(this)) >= uint(amount));
            IERC20(Dai).transferFrom(msg.sender, address(this), uint(amount));
        }
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

    modifier allowedAsset(uint _asset) {
        for(uint i =0; i < predictableAssets.length; i++) {
            require(predictableAssets[i] == _asset);
        }
        _;
    }

    modifier allowedToken(address _token) {
        for(uint i =0; i < predictableAssets.length; i++) {
            require(AcceptedTokens[i] == _token);
        }
        _;
    }

    function claimWinnings(uint128 _day, uint _asset) public {
        //logic to see if the person had a winning prediction
        require(dayAssetUserPrediction[_day][_asset][msg.sender] == dayAssetClosePrice[_day][_asset]);
        IERC20(Dai).transfer(
            msg.sender, (dayAssetTotalAmount[_day][_asset]) * 90/100
        );
        
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
    function sendToIba() private onlyOwner {
        require(getTime() > dayCloseTime[dayCount -1] + 64800 seconds);
        for (uint128 i = 0; i < predictableAssets.length; i++) {
            uint amount = ((dayAssetTotalAmount[dayCount][predictableAssets[i]]) * 10/100);
            //IERC20(Dai).approve(IBA, amount);
            IERC20(Dai).approve(address(lendingPool), amount);
            lendingPool.deposit(
                Dai,
                uint(amount),
                address(moonSquare),
                0
            );
        }
    }

    
}