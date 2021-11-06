pragma solidity 0.8.2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract StandardToken is ERC20 {
    uint8 internal dec;
    constructor(string memory name, string memory symbol, uint256 initSupply, uint8 decimals_) ERC20(name, symbol) {
        dec = decimals_;
        _mint(msg.sender, initSupply);
    }   
    
    function decimals() public view virtual override returns (uint8) {
         return dec;
    }
}