// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IERC20} from "../interfaces/IERC20.sol";
import {IAPI} from "../interfaces/IAPI.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

error Transfer__Failed();

contract Sprint69 is Ownable, KeeperCompatibleInterface {
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

    struct Round {
        uint256 startTime;
        uint256 endTime;
        uint256 pickEndTime;
        uint256 totalStaked;
        uint256 totalPlayers;
    }
    mapping(uint256 => uint8[]) public s_roundWinningOrder;

    mapping(uint256 => address[]) public s_roundWinners;

    mapping(uint256 => mapping(address => uint8[])) public s_addressPicks;

    constructor(address _paymentToken, address _api) {
        paymentToken = IERC20(_paymentToken);
        apiContract = IAPI(_api);
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
        require(
            block.timestamp <= s_roundInfo[round].pickEndTime,
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
        s_addressPicks[round][msg.sender] = _assets;
        s_roundInfo[round].totalPlayers += 1;
        s_roundInfo[round].totalStaked += 9 ether;
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

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > roundDuration;
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        if ((block.timestamp - lastTimeStamp) > roundDuration) {
            lastTimeStamp = block.timestamp;
            apiContract.requestMultipleParameters();
            setWinningOrder();
            distributeWinnigs();
        }
    }

    function distributeWinnigs() private {
        uint256 _round = round - 1;
        uint256 len = s_roundWinners[_round].length;
        Round storage roundInfo = s_roundInfo[_round];
        if (len == 1) {
            paymentToken.transfer(
                s_roundWinners[_round][0],
                roundInfo.totalStaked
            );
        }
        if (len > 1) {
            for (uint256 i = 0; i < len; i++) {
                paymentToken.transfer(
                    s_roundWinners[_round][i],
                    (roundInfo.totalStaked / len)
                );
            }
        }
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

    function claimWinning(uint256 _round) external {
        require(
            s_addressPicks[_round][msg.sender][0] ==
                s_roundWinningOrder[_round][0]
        );
        require(
            s_addressPicks[_round][msg.sender][2] ==
                s_roundWinningOrder[_round][2]
        );
        require(
            s_addressPicks[_round][msg.sender][3] ==
                s_roundWinningOrder[_round][3]
        );
        require(
            s_addressPicks[_round][msg.sender][4] ==
                s_roundWinningOrder[_round][4]
        );
        require(
            s_addressPicks[_round][msg.sender][5] ==
                s_roundWinningOrder[_round][5]
        );
        s_roundWinners[_round].push(msg.sender);
    }
}
