// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Vault {
    struct Land {
        uint256 price;
        uint256 shares;
        uint256 lastBoughtAt;
        address owner;
    }

    struct Player {
        uint256 landAmount;
        uint256 rewardDebt;
    }

    struct Pool {
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
    }

    uint256 public totalSupply;
    uint16 public MAX_LANDS = 5;
    Pool public pool;
    mapping(address => uint256) public balances;
    mapping(uint256 => Land) public lands;
    mapping(address => Player) public players;

    constructor() {
        // init lands
        for (uint256 i = 0; i < MAX_LANDS; i++) {
            lands[i] = Land(0, 0, 0, address(0));
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    // amount: buyer deposit token to pool
    function updatePool(uint256 _amount) public {
        // Player storage player = players[msg.sender];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (address(this).balance == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        // pool.accRewardPerShare = pool.accRewardPerShare + _amount / address(this).balance;
        pool.accRewardPerShare = pool.accRewardPerShare + _amount / MAX_LANDS;
        pool.lastRewardBlock = block.number;
    }

    // Deposit tokens to pool for reward allocation.
    function deposit(uint256 _amount) public payable {
        Player storage player = players[msg.sender];
        updatePool(_amount);
        if (player.landAmount > 0) {
            uint256 pending = player.landAmount * pool.accRewardPerShare - player.rewardDebt;
            (bool success, ) = msg.sender.call{value: pending}("");
            require(success, "Transfer reward to prev owner failed");
        }
        
        player.landAmount = player.landAmount + 1;
        player.rewardDebt = player.landAmount * pool.accRewardPerShare;
    }

    // Withdraw LP tokens from pool.
    function withdraw(address playerAddr, uint256 _amount) public payable {
        Player storage player = players[playerAddr];
        updatePool(0);
        uint256 pending = player.landAmount * pool.accRewardPerShare - player.rewardDebt;

        (bool success, ) = playerAddr.call{value: pending}("");
        require(success, "Transfer reward to prev owner failed");

        player.landAmount = player.landAmount - 1;
        player.rewardDebt = player.landAmount * pool.accRewardPerShare;
    }

    function claim(address playerAddr) public {
        Player storage player = players[playerAddr];
        updatePool(0);
        uint256 pending = player.landAmount * pool.accRewardPerShare - player.rewardDebt;

        (bool success, ) = playerAddr.call{value: pending}("");
        require(success, "Transfer reward to prev owner failed");

        player.rewardDebt = player.landAmount * pool.accRewardPerShare;
    }

    function getLandAmount(address playerAddr) public view returns (uint256) {
        return players[playerAddr].landAmount;
    }

    function getRewardDebt(address playerAddr) public view returns (uint256) {
        return players[playerAddr].rewardDebt;
    }

    function getAccRewardPerShare() public view returns (uint256) {
        return pool.accRewardPerShare;
    }

}

contract VaultTest is Test {
    Vault public vault;
    address public owner;
    address[] public playerAddrs;

    function setUp() public {
        owner = msg.sender;
        vm.startPrank(owner);
        console2.log("owner: ", owner);
        console2.log("msg.sender: ", msg.sender);

        // deploy contracts
        vault = new Vault();

        // setup players
        for (uint256 i = 1; i <= 5; i++) {
            address player = address(uint160(i));
            playerAddrs.push(player);
            vm.deal(player, 100 wei);
        }

        vm.stopPrank();
    }


    // logAll: log shares, balance, totalSupply, remain
    function logAll() public view {
        console2.log("************************* vault remain", address(vault).balance);
        console2.log("************************* vault accRewardPerShare", vault.getAccRewardPerShare());
        for (uint256 i = 0; i < playerAddrs.length; i++) {
            console2.log("player", playerAddrs[i]);
            console2.log("balance", playerAddrs[i].balance);
            console2.log("landAmount", vault.getLandAmount(playerAddrs[i]));
            console2.log("rewardDebt", vault.getRewardDebt(playerAddrs[i]));
        }
    }

    function testPlay() public {
        // player 0 deposit
        vm.prank(playerAddrs[0]);
        vault.deposit{value: 100 wei}(100 wei);
        vm.roll(block.number+1);
        logAll();

        // player 1 deposit
        vm.prank(playerAddrs[1]);
        vault.deposit{value: 100 wei}(100 wei);
        vm.roll(block.number+1);
        logAll();

        // player 2 deposit
        vm.prank(playerAddrs[2]);
        vault.deposit{value: 100 wei}(100 wei);
        vm.roll(block.number+1);
        logAll();

        // player 0 withdraw
        vm.prank(playerAddrs[0]);
        vault.withdraw(playerAddrs[0], 100 wei);
        vm.roll(block.number+1);
        logAll();

        // player 3 deposit
        vm.prank(playerAddrs[3]);
        vault.deposit{value: 100 wei}(100 wei);
        vm.roll(block.number+1);
        logAll();

        // player 1 claim
        vm.prank(playerAddrs[1]);
        vault.claim(playerAddrs[1]);
        vm.roll(block.number+1);
        logAll();

        // player 2 withdraw
        vm.prank(playerAddrs[2]);
        vault.withdraw(playerAddrs[2], 100 wei);
        vm.roll(block.number+1);
        logAll();

        // player 4 deposit
        vm.prank(playerAddrs[4]);
        vault.deposit{value: 100 wei}(100 wei);
        vm.roll(block.number+1);
        logAll();

        // player 1 claim
        vm.prank(playerAddrs[1]);
        vault.claim(playerAddrs[1]);
        vm.roll(block.number+1);
        logAll();

        // player 1 claim
        vm.prank(playerAddrs[1]);
        vault.claim(playerAddrs[1]);
        vm.roll(block.number+1);
        logAll();

        // player 3 claim
        vm.prank(playerAddrs[3]);
        vault.claim(playerAddrs[3]);
        vm.roll(block.number+1);
        logAll();

        // player 4 claim
        vm.prank(playerAddrs[4]);
        vault.claim(playerAddrs[4]);
        vm.roll(block.number+1);
        logAll();

        
    }


}