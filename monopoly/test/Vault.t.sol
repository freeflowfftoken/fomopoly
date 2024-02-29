// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Vault {
    IERC20 public immutable token;

    uint256 public totalSupply;
    mapping(address => uint256) public balances;

    constructor(IERC20 _token) {
        token = _token;
    }

    function deposit(uint256 amount) public {
        uint shares;
        if (totalSupply == 0) {
            shares = amount;
        } else {
            shares = amount * totalSupply / token.balanceOf(address(this));
        }

        _mint(msg.sender, shares);
        token.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 shares) public {
        uint256 amount = shares * token.balanceOf(address(this)) / totalSupply;
        _burn(msg.sender, shares);
        token.transfer(msg.sender, amount);
    }

    function burnShares(address from, uint256 shares) public {
        _burn(from, shares);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balances[to] += amount;
    }

    function _burn(address from, uint256 amount) internal {
        totalSupply -= amount;
        // balances[from] -= amount;
        balances[from] = 0;
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
        for (uint256 i = 1; i <= 6; i++) {
            address player = address(uint160(i));
            players.push(player);
        }

        vm.stopPrank();
    }

    // function testDepositWithdraw() public {
    //     vm.startPrank(alice);

    //     // test deposit
    //     console2.log("alice balance", token.balanceOf(alice));
    //     assertEq(token.balanceOf(alice), 0);
    //     console2.log("vault balance", token.balanceOf(address(vault)));
    //     assertEq(token.balanceOf(address(vault)), 0);
    //     console2.log("vault totalSupply", vault.totalSupply());
    //     assertEq(vault.totalSupply(), 0);
    //     console2.log("vault alice balance", vault.balances(alice));
    //     assertEq(vault.balances(alice), 0);

    //     token.mint(alice, 100);
    //     token.approve(address(vault), 100);
    //     vault.deposit(100);

    //     console2.log("alice balance", token.balanceOf(alice));
    //     assertEq(token.balanceOf(alice), 0);
    //     console2.log("vault balance", token.balanceOf(address(vault)));
    //     assertEq(token.balanceOf(address(vault)), 100);
    //     console2.log("vault totalSupply", vault.totalSupply());
    //     assertEq(vault.totalSupply(), 100);
    //     console2.log("vault alice balance", vault.balances(alice));
    //     assertEq(vault.balances(alice), 100);

    //     vault.withdraw(100);

    //     console2.log("alice balance", token.balanceOf(alice));
    //     assertEq(token.balanceOf(alice), 100);
    //     console2.log("vault balance", token.balanceOf(address(vault)));
    //     assertEq(token.balanceOf(address(vault)), 0);
    //     console2.log("vault totalSupply", vault.totalSupply());
    //     assertEq(vault.totalSupply(), 0);
    //     console2.log("vault alice balance", vault.balances(alice));
    //     assertEq(vault.balances(alice), 0);

    //     vm.stopPrank();
    // }

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
            console2.log("shares", vault.balanceOf(players[i]));
            console2.log("balance", token.balanceOf(players[i]));
        }
    }

    function boughtLand(address player) public {
        console2.log("*** boughtLand: ", player);
        vm.startPrank(player);
        vault.deposit(token.balanceOf(player));
        vm.stopPrank();
        logAll();
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
        bals[0] = 1000;
        bals[1] = 10000;
        bals[2] = 1000;
        bals[3] = 10000;
        bals[4] = 1000;
        bals[5] = 10000;

        // mint and approve
        for (uint256 i = 0; i < players.length; i++) {
            mintAndApprove(players[i], address(vault), bals[i]);
        }
        logAll();

        boughtLand(players[0]);
        boughtLand(players[1]);
        vault.burnShares(players[0], vault.balanceOf(players[0]));
        boughtLand(players[2]);
        boughtLand(players[3]);
        vault.burnShares(players[2], vault.balanceOf(players[2]));
        boughtLand(players[4]);
        boughtLand(players[5]);
        vault.burnShares(players[4], vault.balanceOf(players[4]));

        withdrawReward(players[0]);
        withdrawReward(players[1]);
        withdrawReward(players[2]);
        withdrawReward(players[3]);
        withdrawReward(players[4]);
        withdrawReward(players[5]);
    }

}

contract SplitShare is Test {
    uint256 public MAX_LAND = 10;
    
}