// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "../interfaces/TransferHelper.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/DataTypes.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";

import {IERC20} from "../interfaces/IERC20.sol";

import "../interfaces/IRedirect.sol";
import "../interfaces/IGovernanceToken.sol";

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

import "@openzeppelin/contracts/access/Ownable.sol";

contract MoneyHandler is Ownable, KeeperCompatibleInterface {
    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address 
    
    //the Super token used to pay for option premium (sent directly to the NFT and redirected to owner of the NFT)
    ISuperToken private _acceptedToken; // accepted token, 0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09


    ILendingPoolAddressesProvider private provider = ILendingPoolAddressesProvider(
        address(0xd05e3E715d945B59290df0ae8eF85c1BdB684744)
    ); 
    ILendingPool private lendingPool = ILendingPool(provider.getLendingPool());
    address private Dai;

    IRedirect private flowDistributer;
    IGovernanceToken private governanceToken;

    address private _aaveToken = 0x639cB7b21ee2161DF9c882483C9D55c90c20Ca3e;
    
    address[] public contracts;

    uint128 public monthCount;

    uint public payroundStartTime;

    uint256 public totalInIBA;

    uint256 private totalPaid;

    uint128 constant payDayDuration = 30 days;

    struct Charity {
        string name;
        string link; //sends people to the charity's official site
    }

    mapping (address => Charity) public presentCharities;

    string[] private charities;
    address[] public charityAddress;
    
    mapping(uint128 => mapping(string => uint128)) public roundCharityVotes;
    
    mapping(uint128 => address) public roundVoteResults;

    mapping(address => bool) private isAllowed;

    event CharityThisMonth(address indexed charityAddress_, string indexed name_);

    constructor(
        ISuperfluid host,//0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3
        IConstantFlowAgreementV1 cfa,//0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F
        ISuperToken acceptedToken,//0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09
        address dai
    ) 
    {
        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;
        Dai = dai;
        payroundStartTime = block.timestamp;
    }

    function upgradeToken(uint256 amount) private {
        IERC20(Dai).approve(address(_acceptedToken), amount);
        _acceptedToken.upgrade(amount);
    }



    function updateFlow(int96 flowRate) private {
        _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.updateFlow.selector,
                _acceptedToken,
                address(flowDistributer),//address to the distributer that sends funds to charity and Dao
                flowRate, //should be the total amount of Interest withdrawnfrom the IBA divided by the number of seconds in the withdrawal interval
                new bytes(0) // placeholder
            ),
            "0x"
        );
    }


    function createFlow(int96 flowRate) private {
        _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.createFlow.selector,
                _acceptedToken,
                address(flowDistributer),//address to the distributer that sends funds to charity and Dao
                flowRate, //should be the total amount of Interest withdrawnfrom the IBA divided by the number of seconds in the withdrawal interval
                new bytes(0) // placeholder
            ),
            "0x"
        );
    }

    function checkUpkeep(
        bytes calldata /*checkData*/
    ) external view override returns (
        bool upkeepNeeded, bytes memory performData
    ) {
        upkeepNeeded = (block.timestamp >= (payroundStartTime + 30 days));
    }

    function performUpkeep(bytes calldata performData) external override {
        if (block.timestamp >= (payroundStartTime + 30 days)) {
            payroundStartTime = block.timestamp;
            withdrawInterest();
            setwinningCharity();
        }
    }
    function setwinningCharity() private {
        uint128 winning_votes = 0;
        uint index = charities.length +1;
        for (uint i =0; i < charities.length; i++) {
            if (roundCharityVotes[monthCount][charities[i]] > winning_votes){
                winning_votes = roundCharityVotes[monthCount][charities[i]];
                roundVoteResults[monthCount] = charityAddress[i];
                index = i;
            }
        }
        flowDistributer.changeReceiverAdress(roundVoteResults[monthCount]);
        emit CharityThisMonth(roundVoteResults[monthCount], charities[index]);
    }

    function addCharity(
        string memory _charityName,
        address _charityAddress,
        string memory _link
    ) external onlyOwner {
        presentCharities[_charityAddress].name = _charityName;
        presentCharities[_charityAddress].link = _link;
        charities.push(_charityName);
        charityAddress.push(_charityAddress);
    }

    function voteForCharity(string memory charity) external {
        require(isAllowed[msg.sender] == true);
        roundCharityVotes[monthCount][charity] += 1;
    }

    function distributeToMembers() private {
        require(monthCount != 0);
        uint256 cashAmount = _acceptedToken.balanceOf(address(governanceToken));
        governanceToken.distribute(
            cashAmount
        );
    }

    function withdrawRoundFunds(uint amount_) external {
        require(isAllowed[msg.sender] == true);
        lendingPool.withdraw(
            Dai,
            amount_,
            msg.sender
        );
        totalPaid += amount_;
    }

    function withdrawInterest() private {
        uint availableBalance = IERC20(_aaveToken).balanceOf(address(this)) - totalInIBA;
        uint interest = (availableBalance *10)/100;
        lendingPool.withdraw(
            Dai,
            interest,
            address(this)
        );
        upgradeToken(interest);
        int256 toInt = int256(interest);
        (,int96 outflowRate,,) = _cfa.getFlow(_acceptedToken, address(this), address(flowDistributer));
        int96 expectedFR = int96(toInt / 30 days);
        if (outflowRate == 0) {
            createFlow(expectedFR);
        }
        else if (outflowRate < expectedFR) {
            updateFlow(expectedFR);
        }
        monthCount += 1;
    }

        //puts the 10% from daily rocket into account
    function acountForDRfnds() external {
        require(isAllowed[msg.sender] == true);
        totalInIBA += 9000000000000000000;
    }
    //adds contracts that call core funtions
    function addContract(address _conAddress) external onlyOwner{
        isAllowed[_conAddress] = true;
    }

    //adds the flow distributor
    function addFlowDistributor(IRedirect addr) external onlyOwner {
        flowDistributer = addr;
    }
    function addGovernanceToken(IGovernanceToken _gtAdress) external onlyOwner {
        governanceToken = _gtAdress;
    }

    function getCharity(uint index) public view returns(string memory ) {
        return charities[index];
    }
    function getNumberOfCharities() public view returns(uint) {
        return charities.length;
    }
}