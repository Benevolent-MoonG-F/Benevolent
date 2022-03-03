// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ERC721Adminstrable is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => address) private _tokenAdmin;//token admin
    mapping(uint256 => bool) private _tokenIsUnderAdmin;//status of the token admin, true if the admin is set
    mapping(uint256 => address) private holder;//could specify the person who currently holds the token not the owner NOTE: currently unused 
    mapping(uint256 => mapping(address => address)) private _tokenIdApprover;

    event AdminSet (uint256 indexed tokenId, address indexed admin, address indexed owner);
    constructor() ERC721("Admin Sample", "AS") {

    }

    function getAdmin(uint256 tokenId) public view returns(address) {
        return _tokenAdmin[tokenId];
    }

    function setAdmin(
        uint256 tokenId_,
        address admin_
    ) public {
        require(
            _tokenAdmin[tokenId_] == address(0) && _msgSender() == ownerOf(tokenId_) ||
            _isApprovedOrOwner(_msgSender(), tokenId_) == true || 
            _msgSender() == _tokenAdmin[tokenId_]
        );

        _setAdmin(tokenId_, admin_);
    }

    function _setAdmin(
        uint256 tokenId_,
        address admin_
    ) private {
        _tokenAdmin[tokenId_] = admin_;
        _tokenIsUnderAdmin[tokenId_] = true;
    }

    function renounceAdminRole(uint256 tokenId) public {
        require(_tokenAdmin[tokenId] == _msgSender(), "not current Admin");
        _tokenAdmin[tokenId] = address(0);
    }
    function safeMint() public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_msgSender(), tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        if (_tokenIsUnderAdmin[tokenId] == true) {
            require(
                _msgSender() == _tokenAdmin[tokenId]
                || _tokenIdApprover[tokenId][_msgSender()] == _tokenAdmin[tokenId],
                "you are not token admin"
            );
            _transfer(from, to, tokenId);
            _setAdmin(tokenId, _msgSender());
        }
        else {
            require(
                _isApprovedOrOwner(
                    _msgSender(),
                    tokenId
                ),
                "ERC721: transfer caller is not owner nor approved"
            );
            _transfer(from, to, tokenId);
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {

        if (_tokenIsUnderAdmin[tokenId] == true) {
            require(
                _msgSender() == _tokenAdmin[tokenId] 
                || 
                _tokenIdApprover[tokenId][_msgSender()] == _tokenAdmin[tokenId],
                "ERC721: you are not token admin"
            );
            _safeTransfer(from, to, tokenId, _data);
            _setAdmin(tokenId, _msgSender());
        }
        else {
            require(
                _isApprovedOrOwner(
                    _msgSender(),
                    tokenId
                ),
                "ERC721: transfer caller is not owner nor approved"
            );
            _safeTransfer(from, to, tokenId, _data);
        }
    }

    function approve(
        address to,
        uint256 tokenId
    ) public override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        if (_tokenIsUnderAdmin[tokenId] == true) {
            require(_msgSender() == _tokenAdmin[tokenId], "ERC721: you are not token admin");
            _approve(to, tokenId);
            _tokenIdApprover[tokenId][to] = _msgSender();
        } else {
            require(
                _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
                "ERC721: approve caller is not owner nor approved for all"
            );
            _approve(to, tokenId);
            _tokenIdApprover[tokenId][to] = _msgSender();
        }
    }
}