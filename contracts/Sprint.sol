// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IERC20} from "../interfaces/IERC20.sol";
import {IAPI} from "../interfaces/IAPI.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "../interfaces/DataTypes.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IHandler.sol";

error Transfer__Failed();

contract Sprint69 is Ownable, KeeperCompatibleInterface {
    ILendingPoolAddressesProvider private provider =
        ILendingPoolAddressesProvider(
            address(0x178113104fEcbcD7fF8669a0150721e231F0FD4B)
        );
    ILendingPool private lendingPool = ILendingPool(provider.getLendingPool());

    //ISwapRouter public immutable swapRouter;
    //uint24 public constant poolFee = 3000;
    IHandler public handler;
    IAPI private apiContract;
    IERC20 public paymentToken;

    uint256 public round;

    uint256 public lastTimeStamp;

    uint256 public constant roundDuration = 4 days;

    mapping(uint8 => string) public s_assetIdentifier;
    //rount info
    mapping(uint256 => Round) public s_roundInfo;

    // Total Staked
    uint256 public s_totalStaked;

    bool private _setWinners;

    bool private _distributeToWinners;

    struct Round {
        uint256 startTime;
        uint256 endTime;
        uint256 pickEndTime;
        uint256 totalStaked;
        uint256 totalPlayers;
    }

    mapping(uint256 => address[]) roundAddresses;

    mapping(uint256 => uint8[]) public s_roundWinningOrder;

    mapping(uint256 => address[]) public s_roundWinners;

    mapping(uint256 => mapping(address => uint8[])) public s_addressPicks;

    event DepositMade(address indexed user, uint8[] picks);

    constructor(
        address _paymentToken,
        address _api,
        address _handler
    ) {
        paymentToken = IERC20(_paymentToken);
        apiContract = IAPI(_api);
        handler = IHandler(_handler);
        round = 1;
        s_roundInfo[1] = Round(
            block.timestamp,
            (block.timestamp + 4 days),
            (block.timestamp + 72 hours),
            0,
            0
        );
        s_assetIdentifier[1] = "USDC";
        s_assetIdentifier[2] = "BNB";
        s_assetIdentifier[3] = "XRP";
        s_assetIdentifier[4] = "SOL";
        s_assetIdentifier[5] = "ADA";
        s_assetIdentifier[6] = "AVAX";
        s_assetIdentifier[7] = "DODGE";
        s_assetIdentifier[8] = "DOT";
        lastTimeStamp = block.timestamp;
    }

    function selectAssets(uint8[] memory _assets) external {
        uint256 _round = round;
        require(
            block.timestamp < (s_roundInfo[round].pickEndTime - 12 hours),
            "pick duration ended"
        );
        bool success = paymentToken.transferFrom(
            msg.sender,
            address(this),
            10 ether
        );
        if (!success) {
            revert Transfer__Failed();
        }
        aaveDeposit(10 ether);
        handler.accountForSprint();
        s_addressPicks[_round][msg.sender] = _assets;
        s_roundInfo[_round].totalPlayers += 1;
        s_roundInfo[_round].totalStaked += 9 ether;
        roundAddresses[_round].push(msg.sender);

        emit DepositMade(msg.sender, _assets);
    }

    function setWinningOrder() private {
        uint256 usdcPrice = apiContract.USDC();
        uint256 bnbprice = apiContract.BNB();
        uint256 xrpPrice = apiContract.XRP();
        uint256 solPrice = apiContract.SOL();
        uint256 adaPrice = apiContract.ADA();
        uint256 avaxPrice = apiContract.AVAX();
        uint256 dodgePrice = apiContract.DODGE();
        uint256 dotPrice = apiContract.DOT();

        uint256[8] memory arrayed = [
            usdcPrice,
            bnbprice,
            xrpPrice,
            solPrice,
            adaPrice,
            avaxPrice,
            dodgePrice,
            dotPrice
        ];
        uint256[] memory _winningOrder;
        for (uint8 i = 0; i < 8; i++) {
            if (arrayed[i] < arrayed[i + 1]) {
                s_roundWinningOrder[round][i] = i + 1;
            }
        }
    }

    function aaveDeposit(uint256 amount) private {
        paymentToken.approve(address(lendingPool), amount);
        lendingPool.deposit(address(paymentToken), amount, address(handler), 0);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if ((block.timestamp - lastTimeStamp) > roundDuration) {
            upkeepNeeded = true;
            performData = abi.encodePacked(uint256(0));
        }
        if (_setWinners == true) {
            upkeepNeeded = true;
            performData = abi.encodePacked(uint256(1));
        }
        if (_distributeToWinners == true) {
            upkeepNeeded = true;
            performData = abi.encodePacked(uint256(2));
        }
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function withdrawFromAave() private {
        lendingPool.withdraw(
            address(paymentToken),
            s_roundInfo[round].totalStaked,
            address(this)
        );
    }

    function performUpkeep(bytes calldata performData) external override {
        uint256 value = abi.decode(performData, (uint256));
        if (value == 0) {
            lastTimeStamp = block.timestamp;
            apiContract.requestMultipleParameters();
            setWinningOrder();
            _setWinners = true;
        }
        if (value == 1) {
            _setWinners = false;
            setWinners(round);
            _distributeToWinners = true;
        }
        if (value == 2) {
            _distributeToWinners = false;
            withdrawFromAave();
            distributeWinnigs();
        }
    }

    function distributeWinnigs() private {
        uint256 _round = round;
        if (s_roundWinners[_round].length != 0) {
            uint256 len = s_roundWinners[_round].length;
            Round storage roundInfo = s_roundInfo[_round];
            if (len == 1) {
                paymentToken.transfer(
                    s_roundWinners[_round][0],
                    roundInfo.totalStaked
                );
            }
            if (len > 1) {
                for (uint256 i = 0; i < len; ) {
                    paymentToken.transfer(
                        s_roundWinners[_round][i],
                        (roundInfo.totalStaked / len)
                    );
                    unchecked {
                        i++;
                    }
                }
            }
        }
        round += 1;
    }

    function replaceAsset(
        uint256 _totalSupply,
        uint8 _id,
        string memory _symbol,
        string memory _shortUrl,
        string memory _url
    ) external onlyOwner {
        apiContract.addAssetUrl(_totalSupply, _symbol, _id, _shortUrl, _url);
        s_assetIdentifier[_id] = _symbol;
    }

    function setWinners(uint256 _round) internal {
        uint8[] storage winningOder = s_roundWinningOrder[_round];
        uint256 numberOfPlayers = roundAddresses[_round].length;
        address[] storage allUsers = roundAddresses[_round];
        for (uint256 i = 0; i < numberOfPlayers; ) {
            address playerAddress = allUsers[i];
            uint256 _winLength = winningOder.length;
            uint256 matchingNumbers;
            uint8[] storage userOrder = s_addressPicks[_round][playerAddress];
            for (uint256 p = 0; p < _winLength; ) {
                if (userOrder[p] == winningOder[p]) {
                    matchingNumbers += 1;
                } else {
                    break;
                }
                unchecked {
                    p++;
                }
            }
            unchecked {
                i++;
            }
            if (matchingNumbers == 6) {
                s_roundWinners[_round].push(playerAddress);
            }
        }
    }
}
