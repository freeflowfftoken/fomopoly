pragma solidity ^0.8.20;

error NotEnoughFMP(uint256 balance, uint256 price);
error NotEnoughETH(uint256 balance, uint256 price);
error NotEnoughTicket(uint256 balance, uint256 price);
error TransferFailed(address from, address to, uint256 amount);
error NotOwnAnyLand(address player);
error NotEnoughProp(uint256 propType, uint256 amount);