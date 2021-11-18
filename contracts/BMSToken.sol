//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';


contract BMSToken is ERC20 {
    constructor() ERC20('BMS Token', 'BMS') {
        _mint(msg.sender, 100000000000000000000000000);
    }
}
