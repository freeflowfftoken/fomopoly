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
        uint256 shares;
        uint256 claimable;
        mapping(uint16 => uint256) claimedOfLand;
    }

    IERC20 public immutable token;

    uint256 public totalSupply;
    uint16 public MAX_LANDS = 5;
    mapping(address => uint256) public balances;
    mapping(uint256 => Land) public lands;
    mapping(address => Player) public players;

    constructor(IERC20 _token) {
        token = _token;

        // init lands
        for (uint256 i = 0; i < MAX_LANDS; i++) {
            lands[i] = Land(0, 0, 0, address(0));
        }
    }

    function buyLand(uint16 position, uint256 amount) public {
        // settle reward for previous owner
        address prevOwnerAddr = lands[position].owner;
        if (prevOwnerAddr != address(0)) {
            Player storage prevOwner = players[prevOwnerAddr];
            uint256 reward = lands[position].shares / totalSupply * token.balanceOf(address(this));
            require(reward >= prevOwner.claimedOfLand[position], "Vault: land reward exceeds claimable");
            uint256 claimable = reward - prevOwner.claimedOfLand[position];
            prevOwner.claimable += claimable;

            // the land bought by others, so reset claimed
            prevOwner.claimedOfLand[position] = 0;

            // burn shares from previous owner
            _burn(prevOwnerAddr, lands[position].shares);
        }

        // transfer token to vault
        token.transferFrom(msg.sender, address(this), amount);

        // calculate shares
        uint shares;
        if (totalSupply == 0) {
            shares = amount / MAX_LANDS;
        } else {
            shares = totalSupply / MAX_LANDS;
        }

        // add shares to buyer
        _mint(msg.sender, shares);
        lands[position].price = amount;
        lands[position].shares = shares;
        lands[position].owner = msg.sender;
        lands[position].lastBoughtAt = block.timestamp;
    }

    function withdraw(uint256 shares) public {
        if (totalSupply == 0) {
            return;
        }
        uint256 amount = shares * token.balanceOf(address(this)) / totalSupply;
        _burn(msg.sender, shares);
        token.transfer(msg.sender, amount);
    }

    function _claimLandReward(address player, uint16 position) internal {
        Player storage p = players[player];
        uint256 reward = lands[position].shares / totalSupply * token.balanceOf(address(this));
        require(reward >= p.claimedOfLand[position], "Vault: land reward exceeds claimable");
        uint256 claimable = reward - p.claimedOfLand[position];
        p.claimable += claimable;
        p.claimedOfLand[position] = reward;
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balances[to] += amount;
    }

    function _burn(address from, uint256 amount) internal {
        totalSupply -= amount;
        balances[from] -= amount;
        // balances[from] = 0;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function sharesSupply() public view returns (uint256) {
        return totalSupply;
    }

    function Remain() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

contract VaultTest is Test {
    Vault public vault;
    ERC20Mock public token;
    address public owner;
    address[] public players;

    function setUp() public {
        owner = msg.sender;
        vm.startPrank(owner);
        console2.log("owner: ", owner);
        console2.log("msg.sender: ", msg.sender);

        // deploy contracts
        token = new ERC20Mock();
        vault = new Vault(IERC20(address(token)));

        // setup players
        for (uint256 i = 1; i <= 20; i++) {
            address player = address(uint160(i));
            players.push(player);
        }

        vm.stopPrank();
    }

    function mintAndApprove(address from, address to, uint256 amount) public {
        vm.startPrank(from);
        token.mint(from, amount);
        token.approve(address(to), amount);
        vm.stopPrank();
    }

    // logAll: log shares, balance, totalSupply, remain
    function logAll() public {
        console2.log("vault sharesSupply", vault.sharesSupply());
        console2.log("vault remain", vault.Remain());
        for (uint256 i = 0; i < players.length; i++) {
            console2.log("player", players[i]);
            console2.log("shares", vault.balanceOf(players[i]));
            console2.log("balance", token.balanceOf(players[i]));
        }
    }

    function bulkBoughtLand(uint16 start, uint16 end) public {
        uint16 count = 0;
        for (uint i = start; i < end; i++) {
            boughtLand(players[i], count);
            count++;
        }
    }

    function boughtLand(address player, uint16 position) public {
        console2.log("*** boughtLand: ", player);
        vm.startPrank(player);
        vault.buyLand(position, token.balanceOf(player));
        vm.stopPrank();
        logAll();
    }

    function allWithdraw() public {
        for (uint256 i = 0; i < players.length; i++) {
            withdrawReward(players[i]);
        }
    }

    function withdrawReward(address player) public {
        console2.log("*** withdrawReward: ", player);
        vm.startPrank(player);
        vault.withdraw(vault.balanceOf(player));
        vm.stopPrank();
        logAll();
    }

    function test2() public {
        uint256[] memory bals = new uint256[](players.length);
        for (uint256 i = 0; i < players.length; i++) {
            bals[i] = 1000;
        }

        // mint and approve
        for (uint256 i = 0; i < players.length; i++) {
            mintAndApprove(players[i], address(vault), bals[i]);
        }
        logAll();

        bulkBoughtLand(0, 5);
        bulkBoughtLand(5, 10);
        bulkBoughtLand(10, 15);
        bulkBoughtLand(15, 20);

        allWithdraw();
    }

}