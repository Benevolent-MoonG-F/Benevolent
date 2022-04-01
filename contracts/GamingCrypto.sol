//SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {DailyRocket} from "./DailyRocket.sol";
import {MoonSquares} from "./MoonSquares.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract BenevolentMoonFactory is Ownable {

    mapping(string => address) private _assetDRAddress;
    mapping(string => address) private _assetMSAddress;

    event DaliyRocketDeployed(address indexed dailyRocket_, string _asset);
    event MoonSquaresDeployed(address indexed moonSquare_, string _asset);

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
        address _handler,
        uint256 midnight_
    ) public pure returns (bytes memory) {
        require(_contract == 1 || _contract == 2);//@dev: wrong contract selection
        if (_contract == 1) {
            bytes memory bytecode = type(MoonSquares).creationCode;

            return abi.encodePacked(
                bytecode,
                abi.encode(
                    _asset,
                    agg,
                    _handler,
                    midnight_
                )
            );

        } else {
            bytes memory bytecode = type(DailyRocket).creationCode;

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


    function deployDailyRocket(
        bytes memory drbytecode,
        uint _salt,
        string memory name_
    ) public payable onlyOwner {
        require(_assetDRAddress[name_] == address(0));
        address addr;
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


        emit DaliyRocketDeployed(addr, name_);
    }


    function deployMoonSquares(
        bytes memory msbytecode,
        uint _salt,
        string memory name_
    ) public payable onlyOwner {
        require(_assetMSAddress[name_] == address(0));
        address addr1;
        assembly {
            addr1 := create2(
                callvalue(),
                add(msbytecode, 0x20),
                mload(msbytecode),
                _salt
            )

            if iszero(extcodesize(addr1)) {
                revert(0, 0)
            }
        }
        _assetMSAddress[name_] = addr1;

        emit MoonSquaresDeployed(addr1, name_);
    }
}