//SPDX-License-Identifier: MIT

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

    IUniswapV2Router01 public sushiRouter = IUniswapV2Router01(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
        address(0x178113104fEcbcD7fF8669a0150721e231F0FD4B)
    ); // mainnet address, for other addresses: https://docs.aave.com/developers/deployed-contracts/deployed-contract-instances 
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    

    address constant IBA = 0x9198F13B08E299d85E096929fA9781A1E3d5d827; //should be aave contact address or the IBA to be used
    address DAO; //address of the Dao contact
    address flowDistrubuter;
    address constant SWAPADRESS = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address Dai = 0xBE91b305EBdb0253aBAfe1Da0cDFb0FD9d4fd4B8;
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

    function setMoonPrice(int price) public onlyOwner {
        roundMoonPrice[coinRound] = price;
        roundStartTime[coinRound] = getTime();
        roundStartPrice[coinRound] = getPrice();

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
        address coin,  /*asset to convert to dai */
        uint256 _end,
        int256 amount
        /*address[] calldata swapPairs*/
    ) public /* allowedToken( allowedPayments[coin]) returns (bytes memory , uint[] memory )*/
    {
        require(amount >= 10000000000000000000);
        if (coin != Dai) {
            IERC20(coin).transferFrom(msg.sender, address(this), uint(amount));
            address[] memory path = new address[](2);
            path[0] = coin;
            path[1] = Dai;
            uint amountOut = 10000000000000000000;
            uint amountIn = sushiRouter.getAmountsIn(
                amountOut,
                path
            )[0];
        
            IERC20(coin).approve(address(sushiRouter), amountIn);
        
        //uint allowed = IERC20(coin).allowance(msg.sender, address(sushiRouter));
        
        //emit test(now+90, amountIn, amountOut, path, allowed, msg.sender);

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

        IERC20(Dai).approve(address(lendingPool), uint(amount));
        lendingPool.deposit(
            Dai,
            uint(amount),
            address(this),
            0
        );

        roundAddressBetsPlaced[coinRound][msg.sender].squareStartTime = _start;
        
        roundAddressBetsPlaced[coinRound][msg.sender].squareEndTime  = _end;
        //update all the relevant arrays
        roundPlayerArray[coinRound].push(msg.sender);
        roundStartTimeArray[coinRound].push(_start);
        roundEndTimeArray[coinRound].push(_end);
        //update the total value played
        roundTotalStaked[coinRound] += uint(amount);
        roundWinnings[coinRound] = (roundTotalStaked[coinRound] * 90)/100;
        emit Predicted(msg.sender, _start, _end);

        /* return (returnData , returnValues );*/


    }

    function getPrice() public view returns(int256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);//returns matic Price 
        (,int256 answer,,,) = priceFeed.latestRoundData();
        return int256(answer * 10000000000);
    }

    function getTime() public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
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

    function withdrawInterest(address aaveToken) private returns(uint) {
        uint aaveBalance = IERC20(aaveToken).balanceOf(address(this));
        uint interest = aaveBalance - (roundTotalStaked[coinRound] - totalPaid);
        /*
        bytes memory payload = abi.encodeWithSignature(
            "withdraw(address, uint, address)",
            Dai,
            interest,
            address(this)
        );
        */
        lendingPool.withdraw(
            Dai,
            interest,
            address(this)
        );
        ISuperToken(_acceptedToken).upgrade(interest);
        return(interest);
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

