//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/TransferHelper.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
} from "@superfluid/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid/interfaces/agreements/IConstantFlowAgreementV1.sol";


import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {
    SuperAppBase
} from "@superfluid/apps/SuperAppBase.sol";
import "../interfaces/IRedirect.sol";
import "../interfaces/IGovernanceToken.sol";


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

    mapping(string => uint256) public coinRound;
    //uint128 public coinRound;

    uint128 public monthCount;

    uint public payroundStartTime;

    uint128 constant payDayDuration = 30 days;

    uint public totalPaid;

    //IUniswapV2Router02 public sushiRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    ILendingPoolAddressesProvider public provider = ILendingPoolAddressesProvider(
        address(0x88757f2f99175387aB4C6a4b3067c77A695b0349)
    ); 
    ILendingPool public lendingPool = ILendingPool(provider.getLendingPool());

    //ISwapRouter public immutable swapRouter;
    //uint24 public constant poolFee = 3000;
    
    IRedirect flowDistrubuter;
    IGovernanceToken governanceToken;

    address Dai = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
    address _aaveToken;
    
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
    }

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
    
    mapping(uint128 => address) public roundVoteResults;
    
    mapping (uint128 => address[]) public winers;

    mapping (uint256 => mapping (string => address[])) public roundCoinPlayerArray;

    mapping (uint256 => mapping (string => uint256[])) private roundCoinStartTimeArray;

    mapping (uint256 => mapping (string => uint256[])) private  roundCoinEndTimeArray;
    
    mapping(uint256 => mapping(string => uint256[])) private roundCoinWinningIndex;

    mapping (uint256 => mapping( string => mapping (address => Bet))) public roundCoinAddressBetsPlaced;

    mapping(uint256 => mapping(string => bool)) public roundCoinWinningIsWinner;

    mapping (address => uint256) totalAmountPlayed;//shows how much every player has placed

    event Predicted(address indexed _placer, uint256 _start, uint _end);
    

    constructor(
        
        //set superfluid specific params, receiver, and accepted token in the constructor
        
        ISuperfluid host,//0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3
        IConstantFlowAgreementV1 cfa,//0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F
        ISuperToken acceptedToken//0xe3cb950cb164a31c66e32c320a800d477019dcff
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
    
    modifier isWinner() {
        for (uint i =0; i< winers[monthCount].length; i++) {
            require(winers[monthCount][i] == msg.sender);
        }
        _;
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
        roundCoinAddressBetsPlaced[coinRound[market]][market][msg.sender].squareStartTime = _start;
        
        roundCoinAddressBetsPlaced[coinRound[market]][market][msg.sender].squareEndTime  = (_start + 1800 seconds);
        //update all the relevant arrays
        roundCoinPlayerArray[coinRound[market]][market].push(msg.sender);
        roundCoinStartTimeArray[coinRound[market]][market].push(_start);
        roundCoinEndTimeArray[coinRound[market]][market].push((_start + 1800 seconds));

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
        return int256(answer);
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
            roundCoinStartTimeArray[coinRound[market]][market][p] >= roundCoinInfo[coinRound[market]][market].winningTime
            &&
            roundCoinEndTimeArray[coinRound[market]][market][p] <= roundCoinInfo[coinRound[market]][market].winningTime
        ) {
            return true;
        } else {
            return false;
        }
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
            if (_checkIndexes(market, p) == true){
                roundCoinWinningIndex[coinRound[market]][market].push(p);
            }
            //round coin start time array of p to be greater or equal to the round coin winning time
        }
        //since squares will be owned by more than one person, we set the index to allow us to delagate the claiming reward function to the user.
    }

    function isAwiner(uint256 _round, string memory market, address checkeAddress) public view returns(bool) {
        if (roundCoinInfo[_round][market].winningTime == 0) {
            return false;
        } else {
            require(roundCoinInfo[_round][market].winningTime != 0);
            require(
                roundCoinAddressBetsPlaced[_round][market][checkeAddress].squareStartTime
                <=
                roundCoinInfo[_round][market].winningTime
            );
            require(
                roundCoinAddressBetsPlaced[_round][market][checkeAddress].squareEndTime
                >=
                roundCoinInfo[_round][market].winningTime
            );
            return true;
        }

    }
    //should use superflid's flow if its just one user & instant distribution if there are several winners

     function givePrize( string memory market) private {
        require(roundCoinWinningIndex[coinRound[market]][market].length != 0);
        if (roundCoinWinningIndex[coinRound[market]][market].length == 1) {
    
            IERC20(Dai).transfer(
                roundCoinPlayerArray[coinRound[market]][market][roundCoinWinningIndex[coinRound[market]][market][0]],
                roundCoinInfo[coinRound[market]][market].winnings
            );
        } else {
            for (uint8 i = 0; i < roundCoinWinningIndex[coinRound[market]][market].length; i++) {
                require(roundCoinPlayerArray[coinRound[market]][market][roundCoinWinningIndex[coinRound[market]][market][i]] == msg.sender);
                IERC20(Dai).transfer(
                    roundCoinPlayerArray[coinRound[market]][market][roundCoinWinningIndex[coinRound[market]][market][i]], 
                    roundCoinInfo[coinRound[market]][market].winnings/roundCoinWinningIndex[coinRound[market]][market].length
                );
            }
        }
        totalPaid += roundCoinInfo[coinRound[market]][market].winnings;

    }

    function setTime(string memory market) private {
        roundCoinInfo[coinRound[market]][market].winningTime = getTime();
        setwinningIndex(market);
        withdrawRoundFundsFromIba(market);
    }

    function checkUpkeep(
        bytes calldata checkData
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
        flowDistrubuter.changeReceiverAdress(roundVoteResults[monthCount]);
        //return charities[i];
    }

    //withdraws the total Amount after the moonpice gets hit
    function withdrawRoundFundsFromIba(string memory market) private {
        require(roundCoinWinningIndex[coinRound[market]][market].length != 0);
        lendingPool.withdraw(
            Dai,
            roundCoinInfo[coinRound[market]][market].winnings,
            address(this)
        );
        
        //Withdraws Funds from the predictions
    }

    function distributeToMembers() private {
        require(monthCount != 0);
        uint256 cashAmount = _acceptedToken.balanceOf(address(governanceToken));
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
            address(this)
        );
        IERC20(Dai).approve(address(_acceptedToken), interest);
        ISuperToken(_acceptedToken).upgrade(interest);
        roundInterestEarned[monthCount] = interest;
        return(interest);
        //remember to upgrade the dai for flow

    }
    //distributes the Interest Earned on the round to members of the Dao
    function flowToPaymentDistributer() private {
        //Flows interest earned from the protocal to the redirectAll contract that handles distribution
            //Flow Winnings
        int256 toInt = int256(roundInterestEarned[monthCount]);
        _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.createFlow.selector,
                _acceptedToken,
                address(flowDistrubuter),//address to the distributer that sends funds to charity and Dao
                (int96(toInt) / 30 days), //should be the total amount of Interest withdrawnfrom the IBA divided by the number of seconds in the withdrawal interval
                new bytes(0) // placeholder
            ),
            "0x"
        );
        monthCount += 1;
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
            0
        );

    }

    function voteForCharity(bytes8 charity) external isWinner {
        roundCharityVotes[monthCount][charity] += 1;
    }

    //adds contracts that call core funtions
    function addContract(address _conAddress) external onlyOwner{
        contracts.push(_conAddress);
    }

    function addGovernanceToken(IGovernanceToken _gtAdress) public isAllowedContract {
        governanceToken = _gtAdress;
    }
    
    //adds winners to the charity voting pool
    function addToWinners(address _winner) external isAllowedContract {
        winers[monthCount].push(_winner);
    }

    //adds the flow distributor
    function addFlowDistributor(IRedirect addr) external onlyOwner {
        flowDistrubuter = addr;
    }
}