//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract SprintApi is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    bytes32 private jobId;
    uint256 private fee;

    // multiple params returned in a single oracle response
    //uint256 public USDC;
    //uint256 public BNB;
    //uint256 public XRP;
    //uint256 public SOL;
    //uint256 public ADA;
    //uint256 public AVAX;
    //uint256 public DODGE;
    //uint256 public DOT;

    mapping(uint8 => uint256) public s_assetValue;

    struct ASSETURL {
        uint256 totalSupply;
        string name;
        string short;
        string url;
    }

    mapping(uint8 => ASSETURL) public s_assetUrl;

    event RequestMultipleFulfilled(
        bytes32 indexed requestId,
        uint256 asset1,
        uint256 asset2,
        uint256 asset3,
        uint256 asset4,
        uint256 asset5,
        uint256 asset6,
        uint256 asset7,
        uint256 asset8
    );

    constructor(
        address _linkToken,
        address _oracle,
        bytes32 _jobId
    ) ConfirmedOwner(msg.sender) {
        setChainlinkToken(_linkToken);
        setChainlinkOracle(_oracle);
        jobId = _jobId;
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    function addAssetUrl(
        uint256 _totalSupply,
        string memory _symbol,
        uint8 _assetId,
        string memory _short,
        string memory _url
    ) external onlyOwner {
        s_assetUrl[_assetId] = ASSETURL(_totalSupply, _symbol, _short, _url);
    }

    /**
     * @notice Request mutiple parameters from the oracle in a single transaction
     */
    function requestMultipleParameters() external {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillMultipleParameters.selector
        );
        for (uint8 i = 1; i < 9; i++) {
            ASSETURL storage assetUrlInfo = s_assetUrl[i];
            req.add(assetUrlInfo.short, assetUrlInfo.url);
            req.add(assetUrlInfo.short, assetUrlInfo.name);
        }
        sendChainlinkRequest(req, fee); // MWR API.
    }

    function fulfillMultipleParameters(
        bytes32 requestId,
        uint256 USDCResponse,
        uint256 BNBResponse,
        uint256 XRPResponse,
        uint256 SOLResponse,
        uint256 ADAResponse,
        uint256 AVAXResponse,
        uint256 DODGEResponse,
        uint256 DOTResponse
    ) public recordChainlinkFulfillment(requestId) {
        emit RequestMultipleFulfilled(
            requestId,
            USDCResponse,
            BNBResponse,
            XRPResponse,
            SOLResponse,
            ADAResponse,
            AVAXResponse,
            DODGEResponse,
            DOTResponse
        );
        uint256[8] memory response = [
            USDCResponse,
            BNBResponse,
            XRPResponse,
            SOLResponse,
            ADAResponse,
            AVAXResponse,
            DODGEResponse,
            DOTResponse
        ];
        for (uint8 i = 1; i < 9; i++) {
            ASSETURL storage infor = s_assetUrl[i];
            s_assetValue[i] = response[i] * infor.totalSupply;
        }
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}
