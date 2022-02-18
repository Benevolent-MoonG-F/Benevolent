//SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;
contract DailyRoketFactory {

    mapping(string => address) private _assetDRAddress;
    mapping(string => address) private _assetMSAddress;

    event Deployed(address indexed dailyRoket, address indexed moonsquare, string _asset);

    function getMSAddress(
        string memory asset_
    ) public view returns(address){
        return _assetMSAddress[asset_];
    }
    function getDRAddress(
        string memory asset_
    ) public view returns(address){
        return _assetDRAddress[asset_];
    }
    function getBytecode(
        uint _contract,
        string memory _asset,
        address agg,
        address _handler
    ) public pure returns (bytes memory) {
        require(_contract == 1 || _contract == 2);//@dev: wrong contract selection
        if (_contract == 1) {
            bytes memory bytecode = type(MoonSquaresContract).creationCode;

            return abi.encodePacked(
                bytecode,
                abi.encode(
                    _asset,
                    agg,
                    _handler
                )
            );

        } else {
            bytes memory bytecode = type(DailyRocketContract).creationCode;

            return abi.encodePacked(
                bytecode,
                abi.encode(
                    _asset,
                    agg,
                    _handler
                )
            );
        }
    }


    function getAddress(bytes memory bytecode, uint _salt)
        public
        view
        returns (address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode))
        );

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint(hash)));
    }



    // 3. Deploy the contract
    // NOTE:
    // Check the event log Deployed which contains the address of the deployed TestContract.
    // The address in the log should equal the address computed from above.
    function deployContract(bytes memory drbytecode, bytes memory msbytecode, uint _salt, string memory name_) public payable {
        address addr;
        address addr1;
        /*
        NOTE: How to call create2

        create2(v, p, n, s)
        create new contract with code at memory p to p + n
        and send v wei
        and return the new address
        where new address = first 20 bytes of keccak256(0xff + address(this) + s + keccak256(mem[p…(p+n)))
              s = big-endian 256-bit value
        */
        assembly {
            addr := create2(
                callvalue(), // wei sent with current call
                // Actual code starts after skipping the first 32 bytes
                add(drbytecode, 0x20),
                mload(drbytecode), // Load the size of code contained in the first 32 bytes
                _salt // Salt from function arguments
            )

            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        _assetDRAddress[name_] = addr;

        assembly {
            addr1 := create2(
                callvalue(), // wei sent with current call
                // Actual code starts after skipping the first 32 bytes
                add(msbytecode, 0x20),
                mload(msbytecode), // Load the size of code contained in the first 32 bytes
                _salt // Salt from function arguments
            )

            if iszero(extcodesize(addr1)) {
                revert(0, 0)
            }
        }
        _assetMSAddress[name_] = addr1;

        emit Deployed(addr, addr1, name_);
    }
}

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

contract DailyRocketContract is Ownable, KeeperCompatibleInterface {

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

    mapping(uint256 => uint256) dayCloseTime; //Closing Time for every asset
    
    address Dai = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;

    uint256 public contractStartTime; //The contract should start at 0000.00 hours
    
    //mapping(uint256 => mapping(string => int256[])) public dayAssetPrediction;

    //mapping(uint256 => mapping(string => address[])) public dayAssetPredictors;

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
        contractStartTime = block.timestamp;
        dayCount = 1;
        dayCloseTime[dayCount - 1] = block.timestamp;//adds a day to the start time. to change to an input later.
    }//instantiate the token addresses upon deployment


    function setNewClosingPrice() internal {
        dayAssetInfo[dayCount].closePrice = getPrice();
    }
/*
    used to simulate winners for testing
*/

    function setClosingPrice(int price) public {
        dayAssetInfo[dayCount].closePrice = price;
    }


    function predictClosePrice( 
        int _prediction
    ) public
    {   
        if (dayCount > 1) {
            require(getTime() <= dayCloseTime[dayCount -1] + 20 hours);//After this time, one cannot
        }
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
        dayCount+=1;
    }

    function selectWinner() private {
        int256 difference = dayAssetInfo[dayCount].closePrice;
        for (uint8 p = 0; p <= dayAssetInfo[dayCount].totalBets; p++){
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
/*
    function setNumberOfWinners() public {
        uint128 day = dayCount;
        for (uint8 p = 0; p <= dayAssetInfo[day][predictableAssets[i]].totalBets; p++) {
            if (
                dayAssetUserPrediction[day][predictableAssets[i]][p].prediction
                ==
                dayAssetInfo[day][predictableAssets[i]].closePrice
            ) {
                dayAssetUserPrediction[day][predictableAssets[i]][p].isWinner = true;
                dayAssetInfo[day][predictableAssets[i]].noOfWinners +=1;
            }
        }
        dayCount++;
    }
*/

    function getDifference(int256 closePrice, int256 playerPrice) private pure returns(int256) {
        if(closePrice > playerPrice) {
            return closePrice - playerPrice;
        } else {
            return playerPrice - closePrice;
        }
    }

    function getWinner(int256 closePrice, int256 playerPrice, int256 difference) private pure returns(bool) {
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
        bytes8 _charity
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
        upkeepNeeded = (dayCloseTime[(dayCount - 1)] + 86400 seconds) >= getTime();
        
    }
    
    function performUpkeep(bytes calldata performData) external override {
        if ((dayCloseTime[(dayCount - 1)] + 86400 seconds) >= getTime()) {
            dayCloseTime[dayCount] = block.timestamp;
            setNewClosingPrice();
            selectWinner();
            sendToIba();
            _getVictor();
        }
    }
    
    //sends non winnings to an interest bearibg account 
    function sendToIba() public {
        require(getTime() > dayCloseTime[dayCount -1] + 64800 seconds);
        uint amount = ((dayAssetInfo[dayCount].totalAmount) * 10/100);
        IERC20(Dai).approve(address(lendingPool), amount);
        lendingPool.deposit(
            Dai,
            uint(amount),
            address(handler),
            0
        );
        handler.acountForDRfnds(amount);
        emit SentToIBA(uint(amount), dayCount);   
    }
}


pragma solidity ^0.8.10;
pragma abicoder v2;

import "../interfaces/TransferHelper.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/DataTypes.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";

import {IERC20} from "../interfaces/IERC20.sol";

import "../interfaces/IRedirect.sol";

import "../interfaces/IHandler.sol";


//make it a super app to allow using superfluid flows and instant distribution
contract MoonSquaresContract is KeeperCompatibleInterface, Ownable {

    string public assetName;
    uint256 public coinRound;

    uint public totalPaid;

    //IUniswapV2Router02 public sushiRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    ILendingPoolAddressesProvider private provider = ILendingPoolAddressesProvider(
        address(0x88757f2f99175387aB4C6a4b3067c77A695b0349)
    ); 
    ILendingPool private lendingPool = ILendingPool(provider.getLendingPool());

    //ISwapRouter public immutable swapRouter;
    //uint24 public constant poolFee = 3000;
    IHandler private handler;
    AggregatorV3Interface private priceFeed;

    address private Dai = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
    address private Daix = 0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09;
    
//
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


    mapping (address => uint256) totalAmountPlayed;//shows how much every player has placed

    event Predicted(address indexed _placer, uint256 indexed _betId, uint256 _start, uint _end);
    

    constructor(
        string memory _asset,
        AggregatorV3Interface feed_,
        IHandler handler_
    ) {
        assetName = _asset;
        priceFeed = feed_;
        handler = handler_;
    }

    function _updateStorage(
        uint _start
    ) internal {
        uint betId = roundInfo[coinRound].totalBets;
        roundIdBetInfo[coinRound][betId].timePlaced = getTime();
        roundIdBetInfo[coinRound][betId].squareStartTime = _start;
        roundAddressBetIds[coinRound][msg.sender].push(betId);
        roundIdBetInfo[coinRound][betId].squareEndTime  = (_start + 300 seconds);
        roundIdBetInfo[coinRound][betId].owner = msg.sender;
        roundInfo[coinRound].totalBets +=1;
        emit Predicted(msg.sender, betId, _start, (_start + 1800 seconds));

    } 
    //predicts an asset
   function predictAsset(
        uint256 _start
    ) external
    {   
        uint amount = 10000000000000000000;
        //uint duration = 300 seconds;
        require(_start > block.timestamp);
        require(IERC20(Dai).allowance(msg.sender, address(this)) >= amount);
        IERC20(Dai).transferFrom(msg.sender, address(this), amount);
        //update the total value played
        roundInfo[coinRound].totalStaked += amount;
        roundInfo[coinRound].winnings += 9000000000000000000;
        totalStaked += amount;
        aaveDeposit(amount);
        _updateStorage(_start);
        handler.acountForDRfnds(1000000000000000000);
        handler.trackWinnings(9000000000000000000);
    }



    function aaveDeposit(uint amount) internal {
        IERC20(Dai).approve(address(lendingPool), amount);
        lendingPool.deposit(
            Dai,
            amount,
            address(handler),
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
        (,,,uint256 answer,) = priceFeed.latestRoundData();
         return uint256(answer);
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

        for (uint256 p =0; p <= roundInfo[coinRound].totalBets; p++) {
            if (_checkIndexes(p) == true){
                roundIdBetInfo[coinRound][p].isWinner = true;
                roundInfo[coinRound].numberOfWinners += 1;
            }
        }
    }

    function isAwiner(
        uint256 _round,
        uint256 checkedId
    )public view returns(bool) {
        return roundIdBetInfo[coinRound][checkedId].isWinner;

    }

     function takePrize(
         uint round,
         uint256 betId,
         bytes8 charity
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

    function setTime() public {
        roundInfo[coinRound].winningTime = getTime();
        setWinningBets();
        withdrawRoundFundsFromIba();
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

    //withdraws the total Amount after the moonpice gets hit
    function withdrawRoundFundsFromIba() private {
        require(roundInfo[coinRound].numberOfWinners != 0);
        handler.withdrawRoundFunds(roundInfo[coinRound].winnings);
            

        //Withdraws Funds from the predictions
    }

    function setMoonPrice(
        int price
    ) external onlyOwner {
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

}
