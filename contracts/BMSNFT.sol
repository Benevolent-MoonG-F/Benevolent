//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;


import {MoonSquares, ISuperToken, IConstantFlowAgreementV1, ISuperfluid} from "./Redirect.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract TradableNft is ERC721, MoonSquares {
    address tokenOwner;
    
  constructor (
    address owner,
    string memory _name,
    string memory _symbol,
    ISuperfluid host,
    IConstantFlowAgreementV1 cfa,
    ISuperToken acceptedToken
  )
    ERC721 ( _name, _symbol)
    MoonSquares (
      host,
      cfa,
      acceptedToken,
      owner
     )
      {
    tokenOwner = owner;
      _mint(tokenOwner, 1);
  }

  //now I will insert a nice little hook in the _transfer, including the RedirectAll function I need
  function _beforeTokenTransfer(
    address /*from*/,
    address to,
    uint256 /*tokenId*/
  ) internal override {
      _changeReceiver(to);
  }
  
  function createNewToken() external /* onlyOwner */{
      _mint(tokenOwner, 1);
  }
}