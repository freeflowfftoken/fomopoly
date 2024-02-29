// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Monopoly, Player, NumberType} from "../src/Monopoly.sol";
import {FomopolyToken} from "../src/FMP.sol";
import {DeployMonopoly} from "../script/Monopoly.s.sol";
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
        console2.log("owner: ", owner);
        console2.log("msg.sender: ", msg.sender);

        // deploy blast
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

    function testMonopolyInit() public {
        vm.startPrank(owner);

        // test owner
        assertEq(msg.sender, monopoly.owner());
        assertEq(msg.sender, fmp.owner());

        // test init
        assertEq(monopoly.maxLands(), 100);
        assertEq(monopoly.prizeShareRate(), 3);
        assertEq(monopoly.treasuryShareRate(), 5);
        assertEq(monopoly.teamShareRate(), 2);
        assertEq(monopoly.increaseRate(), 20);
        assertEq(monopoly.decreaseInterval(), 30 minutes);
        assertEq(monopoly.decreaseRate(), 5);
        assertEq(monopoly.lowestPrice(), 0.005 ether);
        assertEq(monopoly.ticketAmountForLotteryTicket(), 10);
        assertEq(address(monopoly.fmp()), address(fmp));



        vm.stopPrank();
    }

    function testMove() public {
        address player;
        uint16 pos;
        // test move
        uint16[] memory oriPos = new uint16[](totalPlayers);
        uint16[] memory steps = new uint16[](totalPlayers);
        for (uint256 i = 0; i < totalPlayers; i++) {
            player = players[i];
            vm.startPrank(player);
            (oriPos[i],,) = monopoly.getPlayer(player);
            steps[i] = monopoly.move(NumberType.Any);
            vm.stopPrank();

            // new block
            vm.roll(block.number + 1);
        }

        // validate position
        for (uint256 i = 0; i < totalPlayers; i++) {
            player = players[i];
            (pos,,) = monopoly.getPlayer(player);
            assertEq(pos, oriPos[i] + steps[i]);
        }

        // test move from end to start
        player = players[0];
        uint16 totalMove;
        vm.startPrank(player);
        (totalMove, , ) = monopoly.getPlayer(player);
        for (; totalMove < monopoly.maxLands();) {
            totalMove += monopoly.move(NumberType.Any);
            vm.roll(block.number + 1);
        }

        (pos,,) = monopoly.getPlayer(player);
        assertEq(pos, totalMove % monopoly.maxLands());
        vm.stopPrank();
    }

    function testLandPrice() public {
        vm.startPrank(owner);
        monopoly.resetTestSystems();
        monopoly.resetLands();
        vm.stopPrank();

        uint256 prevPrice;
        uint256 newPrice;
        uint256 expectedPrice;

        // check all lands price is lowest land price
        uint256 lowestPrice = monopoly.lowestPrice();
        for (uint16 i = 0; i < monopoly.maxLands(); i++) {
            prevPrice = monopoly.getLandPrice(i);
            assertEq(prevPrice, lowestPrice);
        }

         address player = players[0];

        vm.prank(owner);
        monopoly.setPosition(player, 0);
        
        vm.startPrank(player);
        // player 0 buy land 0
        (uint16 pos,,) = monopoly.getPlayer(player);
        prevPrice = monopoly.getLandPrice(pos);
        (bool success,) = address(monopoly).call{value: prevPrice}(abi.encodeWithSignature("buyLand()"));
        assertEq(success, true);

        // check land 0 price is increased by increaseRate
        newPrice = monopoly.getLandPrice(pos);
        console2.log("prevPrice: ", prevPrice);
        console2.log("newPrice: ", newPrice);
        expectedPrice = prevPrice + prevPrice * monopoly.increaseRate() / 100;
        console2.log("expected pirce: ", expectedPrice);
        assertEq(newPrice, expectedPrice);

        // check land 0 price is decreased by decreaseRate and decreseInterval
        uint256 decreaseInterval = monopoly.decreaseInterval();
        uint256 decreaseTimes = 3;
        prevPrice = monopoly.getLandPrice(pos);
        vm.roll(block.number + decreaseInterval*decreaseTimes);
        vm.warp(block.timestamp + decreaseInterval*decreaseTimes);
        newPrice = monopoly.getLandPrice(pos);
        console2.log("newPrice: ", newPrice);
        expectedPrice = prevPrice - (prevPrice * monopoly.decreaseRate() / 100) * decreaseTimes;
        console2.log("expected pirce: ", expectedPrice);
        assertEq(newPrice, expectedPrice);

        // check land 0 price is lowestPrice
        prevPrice = monopoly.getLandPrice(pos);
        decreaseTimes = 100;
        vm.roll(block.number + decreaseInterval*decreaseTimes);
        vm.warp(block.timestamp + decreaseInterval*decreaseTimes);
        newPrice = monopoly.getLandPrice(pos);
        assertEq(newPrice, lowestPrice);

        // test view functions
        (, uint256 count) = monopoly.allOwners();
        assertEq(count, 1);

        uint256[] memory landPrices = monopoly.getAllLandPrice(0, monopoly.maxLands());
        assertEq(landPrices.length, monopoly.maxLands());

        uint16[] memory landIDs = monopoly.getPlayerOwnedLandIDs(player);
        assertEq(landIDs.length, 1);
        assertEq(landIDs[0], pos);

        vm.stopPrank();
    }

    function logAllLandPrice() public {
        for (uint16 i = 0; i < monopoly.maxLands(); i++) {
            uint256 price = monopoly.getLandPrice(i);
            console2.log("land: ", i);
            console2.log("price: ", price);
        }
    }

    function testBuyLand() public {
        // set players to each land
        vm.startPrank(owner);
        for (uint16 i = 0; i < totalPlayers; i++) {
            address player = players[i];
            monopoly.setPosition(player, i);
        }
        vm.stopPrank();

        bool rollBlock = true;
        allPlayerBuyLand(rollBlock);
        logAllLands();

        allPlayersMoveOneStep(rollBlock);
        allPlayerBuyLand(rollBlock);
        allPlayerClaimReward(rollBlock);

        logAllPlayers();
        logPool();
    }

    function testBuyLandOneBlock() public {
        // set players to each land
        vm.startPrank(owner);
        for (uint16 i = 0; i < totalPlayers; i++) {
            address player = players[i];
            monopoly.setPosition(player, i);
        }
        vm.stopPrank();

        bool rollBlock = false;
        allPlayerBuyLand(rollBlock);
        logAllLands();

        allPlayersMoveOneStep(rollBlock);
        allPlayerBuyLand(rollBlock);
        // allPlayerClaimReward(rollBlock);

        logAllPlayers();
        logPool();
    }

    function allPlayerBuyLand(bool roolBlock) public {
        for (uint256 i = 0; i < totalPlayers; i++) {
            address player = players[i];
            vm.startPrank(player);
            
            (uint16 pos,,) = monopoly.getPlayer(player);
            uint256 pirce = monopoly.getLandPrice(pos);
            (bool success,) = address(monopoly).call{value: pirce}(abi.encodeWithSignature("buyLand()"));
            assertEq(success, true);

            vm.stopPrank();
            if (roolBlock) {
                vm.roll(block.number + 1);
            }
            logPool();
        }
    }

    function allPlayerClaimReward(bool roolBlock) public {
        for (uint256 i = 0; i < totalPlayers; i++) {
            address player = players[i];
            vm.startPrank(player);
            monopoly.claimReward();
            vm.stopPrank();
            if (roolBlock) {
                vm.roll(block.number + 1);
            }
        }
    }

    function allPlayersMoveOneStep(bool roolBlock) public {
        for (uint256 i = 0; i < totalPlayers; i++) {
            address player = players[i];
            vm.startPrank(owner);
            (uint16 pos,,) = monopoly.getPlayer(player);
            monopoly.setPosition(player, pos+1);
            vm.stopPrank();
            if (roolBlock) {
                vm.roll(block.number + 1);
            }
        }
    }

    // TODO: test claim reward

    // helper functions
    function logAllLands() public view {
        for (uint16 i = 0; i < monopoly.maxLands(); i++) {
            (uint256 price, uint256 lastBoughtAt, address _owner) = monopoly.getLand(i);
            console2.log("land: ", i);
            console2.log("owner: ", _owner);
            console2.log("price: ", price);
            console2.log("lastBoughtAt: ", lastBoughtAt);
            logPool();
        }
    }

    function logAllPlayers() public view {
        for (uint256 i = 0; i < totalPlayers; i++) {
            address player = players[i];
            (uint16 position, uint256 landAmount, uint256 rewardDebt) = monopoly.getPlayer(player);
            console2.log("player: ", player);
            console2.log("balance: ", player.balance);
            console2.log("position: ", position);
            console2.log("landAmount: ", landAmount);
            console2.log("rewardDebt: ", rewardDebt);
        }
    }

    function logPool() public view {
        (uint256 accRewardPerShare, uint256 lastRewardBlock) = monopoly.getPool();
        console2.log("lastRewardBlock: ", lastRewardBlock);
        console2.log("accRewardPerShare: ", accRewardPerShare);
        console2.log("pool balance: ", address(monopoly).balance);
    }

}
