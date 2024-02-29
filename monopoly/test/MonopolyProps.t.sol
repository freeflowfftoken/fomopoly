// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Monopoly, Player, NumberType, Props, PropPaymentType} from "../src/Monopoly.sol";
import {FomopolyToken} from "../src/FMP.sol";
import {DeployMonopoly} from "../script/Monopoly.s.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {NotEnoughFMP, NotEnoughETH, TransferFailed, NotOwnAnyLand, NotEnoughProp} from "../src/common/common.sol";
import "./mocks/MockBlast.sol";


contract MonopolyTest is Test {
    DeployMonopoly public deployMonopoly;
    Monopoly public monopoly;
    FomopolyToken public fmp;
    address public owner;
    uint256 public totalPlayers = 10;
    address[] public players;
    uint256 initFund = 1 ether;

    function setUp() public {
        owner = msg.sender;
        vm.startPrank(owner);

        // deploy blast implmentation
        MockBlast blast = new MockBlast();

        // deploy contracts
        deployMonopoly = new DeployMonopoly();

        address fmpProxy = deployMonopoly.deployFMPToken();
        (bool success, bytes memory result) = address(deployMonopoly).delegatecall(abi.encodeWithSignature("initFMPToken(address)", fmpProxy));
        assertEq(success, true);

        address payable monopolyProxy = deployMonopoly.deployMonopoly();
        (success, result) = address(deployMonopoly).delegatecall(
            abi.encodeWithSignature(
                "initMonopoly(address,address,address)", monopolyProxy, fmpProxy, address(blast)
            )
        );
        assertEq(success, true);

        // setup
        monopoly = Monopoly(payable(monopolyProxy));
        fmp = FomopolyToken(fmpProxy);

        // setup players
        for (uint256 i = 0; i < totalPlayers; i++) {
            address player = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            players.push(player);
        }

        vm.stopPrank();
    }

    function testBuyProps() public {
        uint256 bal;
        bool success;
        address player = players[0];
        uint256[] memory propPricesETH = monopoly.getPropPricesETH();
        vm.startPrank(player);

        uint256 buyAmount = 1;
        _expectRevertNotEnoughETH(player.balance, propPricesETH[uint256(Props.OddDice)]);
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.OddDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.OddDice, buyAmount));
        _expectRevertNotEnoughETH(player.balance, propPricesETH[uint256(Props.EvenDice)]);
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.EvenDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.EvenDice, buyAmount));
        _expectRevertNotEnoughETH(player.balance, propPricesETH[uint256(Props.LowDice)]);
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.LowDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.LowDice, buyAmount));
        _expectRevertNotEnoughETH(player.balance, propPricesETH[uint256(Props.HighDice)]);
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.HighDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.HighDice, buyAmount));
        _expectRevertNotEnoughETH(player.balance, propPricesETH[uint256(Props.LandFlipper)]);
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.LandFlipper)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.LandFlipper, buyAmount));
        
        // fund player with 1 ether
        vm.deal(player, 1 ether);

        bal = player.balance;
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.OddDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.OddDice, buyAmount));
        assertEq(success, true);
        assertEq(player.balance, bal - propPricesETH[uint256(Props.OddDice)]);

        bal = player.balance;
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.EvenDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.EvenDice, buyAmount));
        assertEq(success, true);
        assertEq(player.balance, bal - propPricesETH[uint256(Props.EvenDice)]);

        bal = player.balance;
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.LowDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.LowDice, buyAmount));
        assertEq(success, true);
        assertEq(player.balance, bal - propPricesETH[uint256(Props.LowDice)]);

        bal = player.balance;
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.HighDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.HighDice, buyAmount));
        assertEq(success, true);
        assertEq(player.balance, bal - propPricesETH[uint256(Props.HighDice)]);

        bal = player.balance;
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.LandFlipper)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.LandFlipper, buyAmount));
        assertEq(success, true);
        assertEq(player.balance, bal - propPricesETH[uint256(Props.LandFlipper)]);

        uint256[] memory props = monopoly.getPlayerProps(player);
        assertEq(props[uint256(Props.OddDice)], 1);
        assertEq(props[uint256(Props.EvenDice)], 1);
        assertEq(props[uint256(Props.LowDice)], 1);
        assertEq(props[uint256(Props.HighDice)], 1);
        assertEq(props[uint256(Props.LandFlipper)], 1);

        vm.stopPrank();
    }

    function testBuyPropsWithFMP() public {
        uint256 bal;
        address player = players[0];
        uint256[] memory propPricesFMP = monopoly.getPropPricesFMP();
        uint256 buyAmount = 1;

        vm.startPrank(player);
        _expectRevertNotEnoughFMP(fmp.balanceOf(player), propPricesFMP[uint256(Props.OddDice)]);
        monopoly.buyPropsWithFMP(Props.OddDice, buyAmount);
        _expectRevertNotEnoughFMP(fmp.balanceOf(player), propPricesFMP[uint256(Props.EvenDice)]);
        monopoly.buyPropsWithFMP(Props.EvenDice, buyAmount);
        _expectRevertNotEnoughFMP(fmp.balanceOf(player), propPricesFMP[uint256(Props.LowDice)]);
        monopoly.buyPropsWithFMP(Props.LowDice, buyAmount);
        _expectRevertNotEnoughFMP(fmp.balanceOf(player), propPricesFMP[uint256(Props.HighDice)]);
        monopoly.buyPropsWithFMP(Props.HighDice, buyAmount);
        _expectRevertNotEnoughFMP(fmp.balanceOf(player), propPricesFMP[uint256(Props.LandFlipper)]);
        monopoly.buyPropsWithFMP(Props.LandFlipper, buyAmount);
        vm.stopPrank();

        // mint 1000 FMP to player
        vm.prank(owner);
        fmp.mint(player, 1000 ether);

        vm.startPrank(player);
        fmp.approve(address(monopoly), fmp.balanceOf(player));

        bal = fmp.balanceOf(player);
        monopoly.buyPropsWithFMP(Props.OddDice, buyAmount);
        assertEq(fmp.balanceOf(player), bal - propPricesFMP[uint256(Props.OddDice)]);

        bal = fmp.balanceOf(player);
        monopoly.buyPropsWithFMP(Props.EvenDice, buyAmount);
        assertEq(fmp.balanceOf(player), bal - propPricesFMP[uint256(Props.EvenDice)]);

        bal = fmp.balanceOf(player);
        monopoly.buyPropsWithFMP(Props.LowDice, buyAmount);
        assertEq(fmp.balanceOf(player), bal - propPricesFMP[uint256(Props.LowDice)]);

        bal = fmp.balanceOf(player);
        monopoly.buyPropsWithFMP(Props.HighDice, buyAmount);
        assertEq(fmp.balanceOf(player), bal - propPricesFMP[uint256(Props.HighDice)]);

        bal = fmp.balanceOf(player);
        monopoly.buyPropsWithFMP(Props.LandFlipper, buyAmount);
        assertEq(fmp.balanceOf(player), bal - propPricesFMP[uint256(Props.LandFlipper)]);

        uint256[] memory props = monopoly.getPlayerProps(player);
        assertEq(props[uint256(Props.OddDice)], 1);
        assertEq(props[uint256(Props.EvenDice)], 1);
        assertEq(props[uint256(Props.LowDice)], 1);
        assertEq(props[uint256(Props.HighDice)], 1);
        assertEq(props[uint256(Props.LandFlipper)], 1);

        vm.stopPrank();
    }

    function testPropFuntionalities() public {
        address player = players[0];
        bool success;
        uint256[] memory propPricesETH = monopoly.getPropPricesETH();

        // fund player with 1 ether
        vm.deal(player, 1 ether);

        vm.startPrank(player);

        // buy each prop
        uint256 buyAmount = 1;
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.OddDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.OddDice, buyAmount));
        assertEq(success, true);
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.EvenDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.EvenDice, buyAmount));
        assertEq(success, true);
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.LowDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.LowDice, buyAmount));
        assertEq(success, true);
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.HighDice)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.HighDice, buyAmount));
        assertEq(success, true);
        (success,) = payable(address((monopoly))).call{value: propPricesETH[uint256(Props.LandFlipper)]}(abi.encodeWithSignature("buyProps(uint8,uint256)", Props.LandFlipper, buyAmount));
        assertEq(success, true);

        // use each type of dice
        uint256 steps = monopoly.move(NumberType.Odd);
        assertEq(steps%2, 1);
        steps = monopoly.move(NumberType.Even);
        assertEq(steps%2, 0);
        steps = monopoly.move(NumberType.Low);
        assertEq(steps <= 3, true);
        steps = monopoly.move(NumberType.High);
        assertEq(steps >= 4, true);

        // use land flipper
        (uint16 pos,,) = monopoly.getPlayer(player);
        uint256 prevPrice = monopoly.getLandPrice(pos);
        (success,) = address(monopoly).call{value: prevPrice}(abi.encodeWithSignature("buyLand()"));
        assertEq(success, true);
        prevPrice = monopoly.getLandPrice(pos);
        monopoly.flipLandPrice(pos);
        assertEq(monopoly.getLandPrice(pos), prevPrice * 2);
        
        
        // because each new player got each prop, so there should be 1 left for each prop
        uint256[] memory props = monopoly.getPlayerProps(player);
        assertEq(props[uint256(Props.OddDice)], 1);
        assertEq(props[uint256(Props.EvenDice)], 1);
        assertEq(props[uint256(Props.LowDice)], 1);
        assertEq(props[uint256(Props.HighDice)], 1);
        assertEq(props[uint256(Props.LandFlipper)], 1);

        vm.stopPrank();
    }

    function testNotEnoughProps() public {
        address player = players[0];
        bool success;
        uint256[] memory propPricesETH = monopoly.getPropPricesETH();

        // make the player exisit
        vm.prank(owner);
        monopoly.setPosition(player, 0);

        vm.startPrank(player);

        // use all props
        _expectRevertNotEnoughProp(Props.OddDice, 1);
        monopoly.move(NumberType.Odd);
        _expectRevertNotEnoughProp(Props.EvenDice, 1);
        monopoly.move(NumberType.Even);
        _expectRevertNotEnoughProp(Props.LowDice, 1);
        monopoly.move(NumberType.Low);
        _expectRevertNotEnoughProp(Props.HighDice, 1);
        monopoly.move(NumberType.High);
        (uint16 pos,,) = monopoly.getPlayer(player);
        _expectRevertNotEnoughProp(Props.LandFlipper, 1);
        monopoly.flipLandPrice(pos);

        vm.stopPrank();
    }

    function _expectRevertNotEnoughProp(Props p, uint256 amount) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                NotEnoughProp.selector, p, amount
            )
        );
    }

    function _expectRevertNotEnoughETH(uint256 balance, uint256 price) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                NotEnoughETH.selector, balance, price
            )
        );
    }

    function _expectRevertNotEnoughFMP(uint256 balance, uint256 price) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                NotEnoughFMP.selector, balance, price
            )
        );
    }
}
