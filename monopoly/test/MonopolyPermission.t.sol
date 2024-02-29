// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Monopoly, Player, Props, PropPaymentType} from "../src/Monopoly.sol";
import {FomopolyToken} from "../src/FMP.sol";
import {DeployMonopoly} from "../script/Monopoly.s.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {NotEnoughFMP, NotEnoughETH, TransferFailed, NotOwnAnyLand} from "../src/common/common.sol";
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
            vm.deal(player, initFund);
        }

        vm.stopPrank();
    }

    function testAdminFuntions() public {
        vm.startPrank(owner);

        address player = players[0];
        uint16 position = 5;
        monopoly.setPosition(player, position);
        (uint16 pos,,) = monopoly.getPlayer(player);
        assertEq(pos, position);

        uint16 maxLands = monopoly.maxLands();
        monopoly.setMaxLands(maxLands + 1);
        assertEq(monopoly.maxLands(), maxLands + 1);

        uint256 increaseRate = monopoly.increaseRate();
        monopoly.setIncreaseRate(increaseRate + 1);
        assertEq(monopoly.increaseRate(), increaseRate + 1);

        uint256 decreaseInterval = monopoly.decreaseInterval();
        monopoly.setDecreaseInterval(decreaseInterval + 1);
        assertEq(monopoly.decreaseInterval(), decreaseInterval + 1);

        uint256 decreaseRate = monopoly.decreaseRate();
        monopoly.setDecreaseRate(decreaseRate + 1);
        assertEq(monopoly.decreaseRate(), decreaseRate + 1);

        uint256 lowestPrice = monopoly.lowestPrice();
        monopoly.setLowestPrice(lowestPrice + 1);
        assertEq(monopoly.lowestPrice(), lowestPrice + 1);

        monopoly.resetAllSystems();
        assertEq(monopoly.maxLands(), maxLands);
        assertEq(monopoly.increaseRate(), increaseRate);
        assertEq(monopoly.decreaseInterval(), decreaseInterval);
        assertEq(monopoly.decreaseRate(), decreaseRate);
        assertEq(monopoly.lowestPrice(), lowestPrice);

        monopoly.resetLands();
        for (uint16 i = 0; i < monopoly.maxLands(); i++) {
            (uint256 price, uint256 lastBoughtAt, address _owner) = monopoly.getLand(i);
            assertEq(price, lowestPrice);
            assertEq(lastBoughtAt, 0);
            assertEq(_owner, address(0));
        }

        uint256[] memory propPricesETH = monopoly.getPropPricesETH();
        monopoly.setPropPrice(Props.OddDice, PropPaymentType.ETH, propPricesETH[uint256(Props.OddDice)] + 1);
        assertEq(monopoly.getPropPricesETH()[uint256(Props.OddDice)], propPricesETH[uint256(Props.OddDice)] + 1);
        monopoly.setPropPrice(Props.EvenDice, PropPaymentType.ETH, propPricesETH[uint256(Props.EvenDice)] + 1);
        assertEq(monopoly.getPropPricesETH()[uint256(Props.EvenDice)], propPricesETH[uint256(Props.EvenDice)] + 1);
        monopoly.setPropPrice(Props.LowDice, PropPaymentType.ETH, propPricesETH[uint256(Props.LowDice)] + 1);
        assertEq(monopoly.getPropPricesETH()[uint256(Props.LowDice)], propPricesETH[uint256(Props.LowDice)] + 1);
        monopoly.setPropPrice(Props.HighDice, PropPaymentType.ETH, propPricesETH[uint256(Props.HighDice)] + 1);
        assertEq(monopoly.getPropPricesETH()[uint256(Props.HighDice)], propPricesETH[uint256(Props.HighDice)] + 1);
        monopoly.setPropPrice(Props.LandFlipper, PropPaymentType.ETH, propPricesETH[uint256(Props.LandFlipper)] + 1);
        assertEq(monopoly.getPropPricesETH()[uint256(Props.LandFlipper)], propPricesETH[uint256(Props.LandFlipper)] + 1);

        uint256[] memory propPricesFMP = monopoly.getPropPricesFMP();
        monopoly.setPropPrice(Props.OddDice, PropPaymentType.FMP, propPricesFMP[uint256(Props.OddDice)] + 1);
        assertEq(monopoly.getPropPricesFMP()[uint256(Props.OddDice)], propPricesFMP[uint256(Props.OddDice)] + 1);
        monopoly.setPropPrice(Props.EvenDice, PropPaymentType.FMP, propPricesFMP[uint256(Props.EvenDice)] + 1);
        assertEq(monopoly.getPropPricesFMP()[uint256(Props.EvenDice)], propPricesFMP[uint256(Props.EvenDice)] + 1);
        monopoly.setPropPrice(Props.LowDice, PropPaymentType.FMP, propPricesFMP[uint256(Props.LowDice)] + 1);
        assertEq(monopoly.getPropPricesFMP()[uint256(Props.LowDice)], propPricesFMP[uint256(Props.LowDice)] + 1);
        monopoly.setPropPrice(Props.HighDice, PropPaymentType.FMP, propPricesFMP[uint256(Props.HighDice)] + 1);
        assertEq(monopoly.getPropPricesFMP()[uint256(Props.HighDice)], propPricesFMP[uint256(Props.HighDice)] + 1);
        monopoly.setPropPrice(Props.LandFlipper, PropPaymentType.FMP, propPricesFMP[uint256(Props.LandFlipper)] + 1);
        assertEq(monopoly.getPropPricesFMP()[uint256(Props.LandFlipper)], propPricesFMP[uint256(Props.LandFlipper)] + 1);


        bool success;
        (success,) = address(monopoly).call(abi.encodeWithSignature("emergencyWithdraw()"));
        assertEq(success, true);
        (success,) = address(monopoly).call(abi.encodeWithSignature("withdrawPrizePool()"));
        assertEq(success, true);
        (success,) = address(monopoly).call(abi.encodeWithSignature("withdrawTreasuryPool()"));
        assertEq(success, true);
        (success,) = address(monopoly).call(abi.encodeWithSignature("withdrawTeamPool()"));
        assertEq(success, true);
        (success,) = address(monopoly).call(abi.encodeWithSignature("withdrawFMP()"));
        assertEq(success, true);

        vm.stopPrank();
    }

    function testAdminFunctionShouldFail() public {
        address player = players[0];
        vm.startPrank(player);

        expectRevertOwnableUnauthorizedAccount(player);
        monopoly.setPosition(player, 5);

        expectRevertOwnableUnauthorizedAccount(player);
        monopoly.setMaxLands(1);

        expectRevertOwnableUnauthorizedAccount(player);
        monopoly.setIncreaseRate(1);

        expectRevertOwnableUnauthorizedAccount(player);
        monopoly.setDecreaseInterval(1);

        expectRevertOwnableUnauthorizedAccount(player);
        monopoly.setDecreaseRate(1);

        expectRevertOwnableUnauthorizedAccount(player);
        monopoly.setLowestPrice(1);

        expectRevertOwnableUnauthorizedAccount(player);
        monopoly.resetAllSystems();

        expectRevertOwnableUnauthorizedAccount(player);
        monopoly.resetLands();

        expectRevertOwnableUnauthorizedAccount(player);
        address(monopoly).call(abi.encodeWithSignature("emergencyWithdraw()"));

        expectRevertOwnableUnauthorizedAccount(player);
        address(monopoly).call(abi.encodeWithSignature("withdrawPrizePool()"));

        expectRevertOwnableUnauthorizedAccount(player);
        address(monopoly).call(abi.encodeWithSignature("withdrawTreasuryPool()"));

        expectRevertOwnableUnauthorizedAccount(player);
        address(monopoly).call(abi.encodeWithSignature("withdrawTeamPool()"));

        expectRevertOwnableUnauthorizedAccount(player);
        address(monopoly).call(abi.encodeWithSignature("withdrawFMP()"));

        expectRevertOwnableUnauthorizedAccount(player);
        monopoly.setPropPrice(Props.OddDice, PropPaymentType.ETH, 1);

        vm.stopPrank();
    }

    function expectRevertOwnableUnauthorizedAccount(address addr) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector, addr
            )
        );
    }

}
