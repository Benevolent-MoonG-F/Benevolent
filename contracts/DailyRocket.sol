//SPDX-License-Identifier: MIT

interface IMoonSquares {

  function addToWinners(address _winner) external;

}
interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}
interface ILendingPoolAddressesProvider {
  event MarketIdSet(string newMarketId);
  event LendingPoolUpdated(address indexed newAddress);
  event ConfigurationAdminUpdated(address indexed newAddress);
  event EmergencyAdminUpdated(address indexed newAddress);
  event LendingPoolConfiguratorUpdated(address indexed newAddress);
  event LendingPoolCollateralManagerUpdated(address indexed newAddress);
  event PriceOracleUpdated(address indexed newAddress);
  event LendingRateOracleUpdated(address indexed newAddress);
  event ProxyCreated(bytes32 id, address indexed newAddress);
  event AddressSet(bytes32 id, address indexed newAddress, bool hasProxy);

  function getMarketId() external view returns (string memory);

  function setMarketId(string calldata marketId) external;

  function setAddress(bytes32 id, address newAddress) external;

  function setAddressAsProxy(bytes32 id, address impl) external;

  function getAddress(bytes32 id) external view returns (address);

  function getLendingPool() external view returns (address);

  function setLendingPoolImpl(address pool) external;

  function getLendingPoolConfigurator() external view returns (address);

  function setLendingPoolConfiguratorImpl(address configurator) external;

  function getLendingPoolCollateralManager() external view returns (address);

  function setLendingPoolCollateralManager(address manager) external;

  function getPoolAdmin() external view returns (address);

  function setPoolAdmin(address admin) external;

  function getEmergencyAdmin() external view returns (address);

  function setEmergencyAdmin(address admin) external;

  function getPriceOracle() external view returns (address);

  function setPriceOracle(address priceOracle) external;

  function getLendingRateOracle() external view returns (address);

  function setLendingRateOracle(address lendingRateOracle) external;
}

library DataTypes {
  // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
  struct ReserveData {
    //stores the reserve configuration
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint8 id;
  }

  struct ReserveConfigurationMap {
    uint256 data;
  }

  struct UserConfigurationMap {
    uint256[2] data; // size is _maxReserves / 128 + ((_maxReserves % 128 > 0) ? 1 : 0), but need to be literal
  }

  enum InterestRateMode {NONE, STABLE, VARIABLE}
}

interface ILendingPool {
  event Deposit(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referral
  );

  /**
   * @dev Emitted on withdraw()
   * @param reserve The address of the underlyng asset being withdrawn
   * @param user The address initiating the withdrawal, owner of aTokens
   * @param to Address that will receive the underlying
   * @param amount The amount to be withdrawn
   **/
  event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);

  event Borrow(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint256 borrowRateMode,
    uint256 borrowRate,
    uint16 indexed referral
  );

  event Repay(
    address indexed reserve,
    address indexed user,
    address indexed repayer,
    uint256 amount
  );

  event Swap(address indexed reserve, address indexed user, uint256 rateMode);

  event ReserveUsedAsCollateralEnabled(address indexed reserve, address indexed user);

  event ReserveUsedAsCollateralDisabled(address indexed reserve, address indexed user);

  event RebalanceStableBorrowRate(address indexed reserve, address indexed user);

  event FlashLoan(
    address indexed target,
    address indexed initiator,
    address indexed asset,
    uint256 amount,
    uint256 premium,
    uint16 referralCode
  );

  /**
   * @dev Emitted when the pause is triggered.
   */
  event Paused();

  /**
   * @dev Emitted when the pause is lifted.
   */
  event Unpaused();

  event LiquidationCall(
    address indexed collateralAsset,
    address indexed debtAsset,
    address indexed user,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    address liquidator,
    bool receiveAToken
  );

  event ReserveDataUpdated(
    address indexed reserve,
    uint256 liquidityRate,
    uint256 stableBorrowRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );

  function deposit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;


  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);

  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;


  function repay(
    address asset,
    uint256 amount,
    uint256 rateMode,
    address onBehalfOf
  ) external returns (uint256);

  function swapBorrowRateMode(address asset, uint256 rateMode) external;

  function rebalanceStableBorrowRate(address asset, address user) external;


  function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveAToken
  ) external;


  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata modes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external;


  function getUserAccountData(address user)
    external
    view
    returns (uint256 totalCollateralETH, uint256 totalDebtETH, uint256 availableBorrowsETH, uint256 currentLiquidationThreshold, uint256 ltv, uint256 healthFactor);

  function initReserve(address reserve, address aTokenAddress, address stableDebtAddress, address variableDebtAddress, address interestRateStrategyAddress) external;

  function setReserveInterestRateStrategyAddress(address reserve, address rateStrategyAddress)
    external;

  function setConfiguration(address reserve, uint256 configuration) external;

  /**
   * @dev Returns the configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The configuration of the reserve
   **/
  function getConfiguration(address asset)
    external
    view
    returns (DataTypes.ReserveConfigurationMap memory);

  /**
   * @dev Returns the configuration of the user across all the reserves
   * @param user The user address
   * @return The configuration of the user
   **/
  function getUserConfiguration(address user)
    external
    view
    returns (DataTypes.UserConfigurationMap memory);

  /**
   * @dev Returns the normalized income normalized income of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve's normalized income
   */
  function getReserveNormalizedIncome(address asset) external view returns (uint256);

  function getReserveNormalizedVariableDebt(address asset) external view returns (uint256);

  function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

  function finalizeTransfer(
    address asset,
    address from,
    address to,
    uint256 amount,
    uint256 balanceFromAfter,
    uint256 balanceToBefore
  ) external;

  function getReservesList() external view returns (address[] memory);

  function getAddressesProvider() external view returns (ILendingPoolAddressesProvider);

  function setPause(bool val) external;

  function paused() external view returns (bool);
}

pragma solidity ^0.8.0;

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
    

    uint128 dayCount;//Kepps track of the days

    uint[] predictableAssets;//all assets that a user can predict
    address[] assetPriceAggregators;

    mapping(uint256 => mapping(uint => int256)) dayAssetClosePrice; //Closing Price per asset 

    mapping(uint256 => uint256) dayCloseTime; //Closing Time per asset
    
    address constant IBA = 0x9198F13B08E299d85E096929fA9781A1E3d5d827;//aavelending pool
    address Dai = 0xBE91b305EBdb0253aBAfe1Da0cDFb0FD9d4fd4B8;
    address QuickSwap = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    IMoonSquares moonSquare = IMoonSquares(0xF033ff1c065704E6664d4581884578A9FcE44b69);
    
    

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
        address _dai
        )
    {
        AcceptedTokens.push(_dai);
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
            IERC20(token).transferFrom(msg.sender, address(this), uint(amount));
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
                /*
                bytes memory payload =abi.encodeWithSignature("addToWinners(address)", dayAssetPredictors[day][predictableAssets[i]][p]);
                (bool success, bytes memory returnData) = address(IBA).call(payload);
                require(success);
                return returnData;
                */
            }
        }
    }


    function getTime() public view returns(uint){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
        (,,,uint answer,) = priceFeed.latestRoundData();
         return uint(answer * 10000000000);
    }

    function getPrice(uint256 _aggindex) public view returns(int){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(assetPriceAggregators[_aggindex]);
        (,int answer,,,) = priceFeed.latestRoundData();
         return int(answer * 10000000000);
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
    function sendToIba() public onlyOwner {
        require(getTime() > dayCloseTime[dayCount -1] + 64800 seconds);
        for (uint128 i = 0; i < predictableAssets.length; i++) {
            uint amount = ((dayAssetTotalAmount[dayCount][predictableAssets[i]]) * 10/100);
            IERC20(Dai).approve(IBA, amount);
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