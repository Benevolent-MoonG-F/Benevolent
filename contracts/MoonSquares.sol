//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/DataTypes.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";
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
import "../interfaces/TransferHelper.sol";
import "../interfaces/ISwapRouter.sol";


//make it a super app to allow using superfluid flows and instant distribution
contract MoonSquares is SuperAppBase, KeeperCompatibleInterface, Ownable {
    
    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address 
    
    //the Super token used to pay for option premium (sent directly to the NFT and redirected to owner of the NFT)
    ISuperToken public _acceptedToken; // accepted token, could be the aToken 


    address[] public allowedPayments;//list of all accepted stablecoins for placing a prediction

    string[] public allowedAssets;//All assets that are predicted on the platform
    
    address[] assetPriceAggregators;

    address[] public contracts;

    mapping(string => address) public assetToAggregator;

    mapping(string => uint256) coinRound;
    //uint128 public coinRound;

    uint128 monthCount;

    uint payroundStartTime;

    uint128 constant payDayDuration = 30 days;

    uint totalPaid;

    uint32 public constant PAYMENT_INDEX = 0;

    //IUniswapV2Router02 public sushiRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
        address(0x88757f2f99175387aB4C6a4b3067c77A695b0349)
    ); 
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());

    ISwapRouter public immutable swapRouter;
    uint24 public constant poolFee = 3000;
    

    address constant IBA = 0x9198F13B08E299d85E096929fA9781A1E3d5d827; //should be aave contact address or the IBA to be used
    address DAO; //address of the Dao contact
    address flowDistrubuter;
    address constant SWAPADRESS = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address Dai = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
    address _aaveToken;
    address governanceToken;
    
    mapping (uint256 => mapping(string => int256)) public roundCoinStartPrice;

    mapping(uint256 => mapping(IERC20 => uint256)) roundAssetTotalAmount;
    
    mapping (uint256 => uint256) roundInterestEarned;

    mapping (uint256 => mapping(string => uint256)) public roundCoinWinnings;//90% player winning per asset

    //The target price (moon price) every round per asset
    mapping (uint256 => mapping(string => int256)) public roundCoinMoonPrice;

    //when the rallyprice get's set
    mapping (uint256 => mapping(string => uint256)) public roundCoinStartTime;

    //Total staked on the contract
    mapping (uint256 => mapping(string => uint256)) public roundCoinTotalStaked;

    //time when the price is first hit 
    mapping (uint256 => mapping(string => uint256)) public roundCoinWinningTime;

    uint public totalStaked;

    
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
    
    mapping (uint128 => address[]) public winers;

    mapping (uint256 => mapping (string => address[])) roundCoinPlayerArray;

    mapping (uint256 => mapping (string => uint256[])) roundCoinStartTimeArray;

    mapping (uint256 => mapping (string => uint256[])) roundCoinEndTimeArray;
    
    mapping(uint256 => mapping(string => uint256[])) public roundCoinWinningIndex;

    mapping (uint256 => mapping( string => mapping (address => Bet))) public roundCoinAddressBetsPlaced;

    mapping (address => uint256) totalAmountPlayed;//shows how much every player has placed

    event Predicted(address indexed _placer, uint256 _start, uint _end);
    

    constructor(
        
        //set superfluid specific params, receiver, and accepted token in the constructor
        
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken,
        ISwapRouter _swapRouter
        ) {
        require(address(host) != address(0));
        require(address(cfa) != address(0));
        require(address(acceptedToken) != address(0));
        //require(address(receiver) != address(0));
        //require(!host.isApp(ISuperApp(receiver)));
        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;
        swapRouter = _swapRouter;
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

    function addAssetsAndAggregators(string memory _asset, address _aggregator) public onlyOwner {
        require(allowedAssets.length < 100);
        assetToAggregator[_asset] = _aggregator;
        allowedAssets.push(_asset);
        assetPriceAggregators.push(_aggregator);
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

    function setMoonPrice(int price, string memory market) public onlyOwner {
        roundCoinMoonPrice[coinRound[market]][market] = price;
        roundCoinStartTime[coinRound[market]][market] = getTime();
        roundCoinStartPrice[coinRound[market]][market] = getPrice(market);

    }

    function voteForCharity(bytes8 charity) public isWinner {
        roundCharityVotes[monthCount][charity] += 1;
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
        int256 amount,
        string memory market
        /*address[] calldata swapPairs*/
    ) public allowedToken(coin) /*returns (bytes memory , uint[] memory )*/
    {
        require(amount >= 10000000000000000000);
        if (coin != Dai) {
            require(IERC20(coin).allowance(msg.sender, address(this)) >= uint(amount));
            IERC20(coin).transferFrom(msg.sender, address(this), uint(amount));

            TransferHelper.safeTransferFrom(coin, msg.sender, address(this), amount);

            // Approve the router to spend the specifed `amountInMaximum` of DAI.
            // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
            TransferHelper.safeApprove(coin, address(swapRouter), amount);
            uint amountInMaximum = 15000000000000000000;
            ISwapRouter.ExactOutputSingleParams memory params =
                ISwapRouter.ExactOutputSingleParams({
                    tokenIn: coin,
                    tokenOut: Dai,
                    fee: poolFee,
                    recipient: msg.sender,
                    deadline: block.timestamp,
                    amountOut: amount,
                    amountInMaximum: amountInMaximum,
                    sqrtPriceLimitX96: 0
                });

            // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
            amountIn = swapRouter.exactOutputSingle(params);

            // For exact output swaps, the amountInMaximum may not have all been spent.
            // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
            if (amountIn < amountInMaximum) {
                TransferHelper.safeApprove(DAI, address(swapRouter), 0);
                TransferHelper.safeTransfer(DAI, msg.sender, amountInMaximum - amountIn);
            }

           /*
            address[] memory path = new address[](2);
            path[0] = coin;
            path[1] = Dai;
            uint amountOut = 10000000000000000000;
            uint amountIn = sushiRouter.getAmountsIn(
                amountOut,
                path
            )[0];
            
        
            IERC20(coin).approve(address(sushiRouter), amountIn);

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

        IERC20(Dai).approve(address(lendingPool), uint(amount));
        lendingPool.deposit(
            Dai,
            uint(amount),
            address(this),
            0
        );

        roundCoinAddressBetsPlaced[coinRound[market]][market][msg.sender].squareStartTime = _start;
        
        roundCoinAddressBetsPlaced[coinRound[market]][market][msg.sender].squareEndTime  = _end;
        //update all the relevant arrays
        roundCoinPlayerArray[coinRound[market]][market].push(msg.sender);
        roundCoinStartTimeArray[coinRound[market]][market].push(_start);
        roundCoinEndTimeArray[coinRound[market]][market].push(_end);
        //update the total value played
        roundCoinTotalStaked[coinRound[market]][market] += uint(amount);
        roundCoinWinnings[coinRound[market]][market] = (roundCoinTotalStaked[coinRound[market]][market] * 90)/100;
        emit Predicted(msg.sender, _start, _end);
    }

    function getPrice(string memory market) public view returns(int256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(assetToAggregator[market]);//returns matic Price 
        (,int256 answer,,,) = priceFeed.latestRoundData();
        return int256(answer);
    }

    function getTime() public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
        //Matic network
        (,,,uint256 answer,) = priceFeed.latestRoundData();
         return uint256(answer);
    }

    function setwinningIndex(string memory market) internal {
        /* we iterate over the squareStartTimeArray(of squareStartTime) and the squareEndTimeArray (of squareEndTime) to assertain that the winning time 
           is either equal to them or more than the squareStartTime but less than the squareEndTime
        */
        require(
            roundCoinEndTimeArray[coinRound[market]][market].length
            ==
            roundCoinStartTimeArray[coinRound[market]][market].length
        );
        for (uint256 p =0; p < roundCoinStartTimeArray[coinRound[market]][market].length; p++) {
            require(
                roundCoinStartTimeArray[coinRound[market]][market][p] >= roundCoinWinningTime[coinRound[market]][market]
                &&
                roundCoinEndTimeArray[coinRound[market]][market][p] <= roundCoinWinningTime[coinRound[market]][market]    
            );
            roundCoinWinningIndex[coinRound[market]][market].push(p);
            //round coin start time array of p to be greater or equal to the round coin winning time
        }
        //since squares will be owned by more than one person, we set the index to allow us to delagate the claiming reward function to the user.
    }

    //should use superflid's flow if its just one user & instant distribution if there are several winners

     function givePrize( string memory market) private {
        require(roundCoinWinningIndex[coinRound[market]][market].length != 0);
        if (roundCoinWinningIndex[coinRound[market]][market].length == 1) {
    
            IERC20(Dai).transfer(roundCoinPlayerArray[coinRound[market]][market][roundCoinWinningIndex[coinRound[market]][market][0]], roundCoinWinnings[coinRound[market]][market]);

        } else {
            for (uint8 i = 0; i < roundCoinWinningIndex[coinRound[market]][market].length; i++) {
                require(roundCoinPlayerArray[coinRound[market]][market][roundCoinWinningIndex[coinRound[market]][market][i]] == msg.sender);
                IERC20(Dai).transfer(
                    roundCoinPlayerArray[coinRound[market]][market][roundCoinWinningIndex[coinRound[market]][market][i]], 
                    roundCoinWinnings[coinRound[market]][market]/roundCoinWinningIndex[coinRound[market]][market].length
                );
            }
        }
        totalPaid += roundCoinWinnings[coinRound[market]][market];

    }

    function setTime(string memory market) private {
        roundCoinWinningTime[coinRound[market]][market] = getTime();
        setwinningIndex(market);
        withdrawRoundFundsFromIba(market);
    }

    /*function getRound() public view returns(uint128) {
        return coinRound;
    }
    */

    function checkUpkeep(
        bytes calldata checkData
    ) external view override returns (
        bool upkeepNeeded, bytes memory performData
    ) {
        for (uint256 p = 0; p < allowedAssets.length; p++) {
        
            if (getPrice(allowedAssets[p]) == roundCoinMoonPrice[coinRound[allowedAssets[p]]][allowedAssets[p]]) {
                upkeepNeeded = true;
                return (true, /* address(this).call( */ abi.encodePacked(uint256(p)));
            }
        }
        if (block.timestamp >= payroundStartTime + 30 days) {
            upkeepNeeded = true;
            return (true, abi.encodePacked(uint256(1000)));
        }
        performData = checkData;
        
    }

function performUpkeep(bytes calldata performData) external override {
        uint256 decodedValue = abi.decode(performData, (uint256));
        if(decodedValue <= allowedAssets.length){
            setTime(allowedAssets[decodedValue]);
        }
        if (decodedValue ==1000) {
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
    function withdrawRoundFundsFromIba(string memory market) private {
        require(roundCoinWinningIndex[coinRound[market]][market].length != 0);
        lendingPool.withdraw(
            Dai,
            roundCoinWinnings[coinRound[market]][market],
            address(this)
        );
        
        //Withdraws Funds from the predictions
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
        uint interest = aaveBalance - (totalStaked - totalPaid);
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