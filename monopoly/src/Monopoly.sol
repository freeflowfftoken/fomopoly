// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Test.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {FomopolyToken} from "../src/FMP.sol";
import {IBlast} from "../src/IBlast/IBlast.sol";
import {NotEnoughFMP, NotEnoughETH, TransferFailed, NotOwnAnyLand, NotEnoughProp} from "../src/common/common.sol";

enum Props { 
    OddDice,
    EvenDice,
    LowDice,
    HighDice,
    LandFlipper,
    Ticket, // 10 tickets for 1 lottery ticket
    LotteryTicket,
    WorldWideTravel
    }
enum NumberType { Any, Odd, Even, Low, High }
enum PropPaymentType { ETH, FMP }

struct Land {
    uint256 price;
    uint256 lastBoughtAt;
    uint256 tradingVolume;
    address owner;
}

struct Player {
    bool exist;
    uint16 position;
    uint16 landAmount;
    uint256 rewardDebt;
    mapping(Props => uint256) props;
}

struct Pool {
    uint256 lastRewardBlock;
    uint256 accRewardPerShare;
}

struct SystemPool {
    uint256 prize;
    uint256 treasury;
    uint256 team;
}

contract Monopoly is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint16 public maxLands;
    // rate of prize pool shares per transaction
    uint256 public prizeShareRate;
    // rate of treasury shares per transaction
    uint256 public treasuryShareRate;
    // rate of team shares per transaction
    uint256 public teamShareRate;
    // rate of land price increase every time it's bought
    uint256 public increaseRate;
    // interval of land price decrease
    uint256 public decreaseInterval;
    // rate of land price decrease every time interval
    uint256 public decreaseRate;
    // lowest price of land
    uint256 public lowestPrice;
    // price of props in ETH or FMP
    mapping(Props => mapping(PropPaymentType => uint256)) public propPrices;
    // required ticket amount to buy lottery ticket
    uint256 public ticketAmountForLotteryTicket;
    // fomopoly token contract
    FomopolyToken public fmp;
    // blast yield contract
    IBlast public blast;

    mapping(uint16 => Land) public lands;
    mapping(address => Player) public players;
    Pool internal _pool;
    SystemPool internal _systemPool;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner, address _fmp, address _blast) public initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();

        // init system variables in proxy contract
        maxLands = 100;
        prizeShareRate = 3;
        treasuryShareRate = 5;
        teamShareRate = 2;
        increaseRate = 20;
        decreaseInterval = 30 minutes;
        decreaseRate = 5;
        lowestPrice = 0.005 ether;
        ticketAmountForLotteryTicket = 10;
        fmp = FomopolyToken(_fmp);

        // init props price
        propPrices[Props.OddDice][PropPaymentType.ETH] = 0.001 ether;
        propPrices[Props.EvenDice][PropPaymentType.ETH] = 0.001 ether;
        propPrices[Props.LowDice][PropPaymentType.ETH] = 0.001 ether;
        propPrices[Props.HighDice][PropPaymentType.ETH] = 0.001 ether;
        propPrices[Props.LandFlipper][PropPaymentType.ETH] = 0.01 ether;
        propPrices[Props.WorldWideTravel][PropPaymentType.ETH] = 0.01 ether;
        propPrices[Props.OddDice][PropPaymentType.FMP] = 50 ether;
        propPrices[Props.EvenDice][PropPaymentType.FMP] = 50 ether;
        propPrices[Props.LowDice][PropPaymentType.FMP] = 50 ether;
        propPrices[Props.HighDice][PropPaymentType.FMP] = 50 ether;
        propPrices[Props.LandFlipper][PropPaymentType.FMP] = 500 ether;
        propPrices[Props.WorldWideTravel][PropPaymentType.FMP] = 500 ether;
        

        // init lands
        for (uint16 i = 0; i < maxLands; i++) {
            lands[i] = Land(lowestPrice, 0, 0, address(0)); // price, lastBoughtAt, tradingVolume, owner
        }

        // init blast yield config
        blast = IBlast(_blast);
        blast.configureClaimableYield();
        blast.configureGovernor(_initialOwner); //only this address can claim yield
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _NumberTypeToPropType(NumberType t) internal pure returns (Props) {
        if (t == NumberType.Odd) {
            return Props.OddDice;
        } else if (t == NumberType.Even) {
            return Props.EvenDice;
        } else if (t == NumberType.Low) {
            return Props.LowDice;
        } else if (t == NumberType.High) {
            return Props.HighDice;
        }
        revert("Invalid NumberType");
    }

    // get player initial position by mod address to maxLands
    function _getPlayerInitPos(address player) internal view returns (uint16) {
        return uint16(uint256(uint160(player)) % maxLands);
    }

    // distribute each 1 props to 1 player
    function distributeProps(address player) internal {
        players[player].props[Props.OddDice] += 1;
        players[player].props[Props.EvenDice] += 1;
        players[player].props[Props.LowDice] += 1;
        players[player].props[Props.HighDice] += 1;
        players[player].props[Props.LandFlipper] += 1;
    }

    function move(NumberType t) public returns (uint16) {
        if (t != NumberType.Any) {
            Props prop = _NumberTypeToPropType(t);
            if (players[msg.sender].props[prop] == 0) {
                revert NotEnoughProp(uint256(prop), 1);
            }
            players[msg.sender].props[prop] -= 1;
        }
        
        Player storage player = players[msg.sender];
        if (player.exist == false) {
            player.exist = true;
            player.position = _getPlayerInitPos(msg.sender);
            distributeProps(msg.sender);
        }

        uint16 steps = getRandomNumber(t);
        player.position  = (player.position + steps) % maxLands;
        player.props[Props.Ticket] += 1;
        return steps;
    }

    function worldWideTravel(uint16 pos) public {
        if (players[msg.sender].props[Props.WorldWideTravel] == 0) {
            revert NotEnoughProp(uint256(Props.WorldWideTravel), 1);
        }
        if (pos >= maxLands) {
            revert("Invalid pos");
        }
        players[msg.sender].props[Props.WorldWideTravel] -= 1;
        players[msg.sender].position = pos % maxLands;
    }

    function buyPropsWithFMP(Props prop, uint256 amount) public {
        Player storage player = players[msg.sender];
        uint256 cost = amount * propPrices[prop][PropPaymentType.FMP];
        if (fmp.balanceOf(msg.sender) < cost) {
            revert NotEnoughFMP(fmp.balanceOf(msg.sender), cost);
        }
        fmp.transferFrom(msg.sender, address(this), cost);
        player.props[prop] += amount;
    }

    function buyProps(Props prop, uint256 amount) public payable {
        Player storage player = players[msg.sender];
        uint256 cost = amount * propPrices[prop][PropPaymentType.ETH];
        if (msg.value < cost) {
            revert NotEnoughETH(msg.value, cost);
        }
        player.props[Props(prop)] += amount;
    }

    // Update reward variables of the pool to be up-to-date.
    // amount: buyer deposit token to pool
    function updatePool(uint256 _amount) public {
        // Player storage player = players[msg.sender];
        if (block.number <= _pool.lastRewardBlock) {
            return;
        }
        if (address(this).balance == 0) {
            _pool.lastRewardBlock = block.number;
            return;
        }
        _pool.accRewardPerShare = _pool.accRewardPerShare + _amount / maxLands;
        _pool.lastRewardBlock = block.number;
    }

    function buyLand() public payable playerExisted {
        // check price
        uint16 position = players[msg.sender].position;
        uint256 price = getLandPrice(position);
        if (msg.value < price) {
            revert NotEnoughETH(msg.value, price);
        }

        // settle reward for prev owner
        Land storage land = lands[position];
        Player storage prevOwner = players[land.owner];
        if (land.owner != address(0) && _pool.accRewardPerShare > prevOwner.rewardDebt) {
            uint256 pending = _pool.accRewardPerShare - prevOwner.rewardDebt;
            (bool success, ) = land.owner.call{value: pending}("");
            if (!success) {
                revert TransferFailed(address(this), land.owner, pending);
            }

            // update prev owner
            prevOwner.landAmount -= 1;
            prevOwner.rewardDebt = prevOwner.landAmount * _pool.accRewardPerShare;
        }

        // update pool and settle reward for buyer
        updatePool(msg.value * (100 - prizeShareRate - treasuryShareRate - teamShareRate) / 100);
        Player storage buyer = players[msg.sender];
        if (buyer.landAmount > 0) {
            uint256 pending = buyer.landAmount * _pool.accRewardPerShare - buyer.rewardDebt;
            (bool success, ) = msg.sender.call{value: pending}("");
            if (!success) {
                revert TransferFailed(address(this), msg.sender, pending);
            }
        }

        // update land
        land.price = price * (100 + increaseRate) / 100;
        land.lastBoughtAt = block.timestamp;
        land.owner = msg.sender;
        land.tradingVolume += msg.value;

        // update player
        buyer.landAmount += 1;
        buyer.rewardDebt = buyer.landAmount * _pool.accRewardPerShare;
        buyer.props[Props.Ticket] += 10;

        // update system pool
        _systemPool.prize += msg.value * prizeShareRate / 100;
        _systemPool.treasury += msg.value * treasuryShareRate / 100;
        _systemPool.team += msg.value * teamShareRate / 100;
    }

    function flipLandPrice(uint16 pos) public playerExisted {
        pos = pos % maxLands;
        Land storage land = lands[pos];

        if (players[msg.sender].props[Props.LandFlipper] == 0) {
            revert NotEnoughProp(uint256(Props.LandFlipper), 1);
        }
        players[msg.sender].props[Props.LandFlipper] -= 1;

        if (land.owner != msg.sender) {
            revert("You are not the owner of this land");
        }

        land.price = land.price * 2;
    }

    function claimReward() public {
        Player storage player = players[msg.sender];
        if (player.landAmount == 0) {
            revert NotOwnAnyLand(msg.sender);
        }

        uint256 pending = player.landAmount * _pool.accRewardPerShare - player.rewardDebt;
        (bool success, ) = msg.sender.call{value: pending}("");
        if (!success) {
            revert TransferFailed(address(this), msg.sender, pending);
        }
        player.rewardDebt = player.landAmount * _pool.accRewardPerShare;
    }

    function convertTicketToLotteryTicket() public {
        Player storage player = players[msg.sender];
        if (player.props[Props.Ticket] < ticketAmountForLotteryTicket) {
            revert NotEnoughETH(player.props[Props.Ticket], ticketAmountForLotteryTicket);
        }
        player.props[Props.Ticket] -= ticketAmountForLotteryTicket;
        player.props[Props.LotteryTicket] += 1;
    }

    // admin functions
    function setPosition(address player, uint16 position) public onlyOwner {
        players[player].exist = true;
        players[player].position = position % maxLands;
    }

    function setMaxLands(uint16 _maxLands) public onlyOwner {
        maxLands = _maxLands;
    }

    function setIncreaseRate(uint256 _incrRate) public onlyOwner {
        increaseRate = _incrRate;
    }

    function setDecreaseInterval(uint256 _descInterval) public onlyOwner {
        decreaseInterval = _descInterval;
    }

    function setDecreaseRate(uint256 _descRate) public onlyOwner {
        decreaseRate = _descRate;
    }

    function setLowestPrice(uint256 _lstPrice) public onlyOwner {
        lowestPrice = _lstPrice;
    }

    function setPropPrice(
        Props prop, PropPaymentType t, uint256 price
    ) public onlyOwner {
        propPrices[prop][t] = price;
    }

    function resetAllSystems() public onlyOwner {
        maxLands = 100;
        decreaseInterval = 30 minutes;
        decreaseRate = 5;
        lowestPrice = 0.005 ether;
        increaseRate = 20;
        ticketAmountForLotteryTicket = 10;
    }

    function resetTestSystems() public onlyOwner {
        maxLands = 10;
        decreaseInterval = 30 minutes;
        decreaseRate = 5;
        lowestPrice = 100 wei;
        increaseRate = 20;
        ticketAmountForLotteryTicket = 10;
    }

    function resetLands() public onlyOwner {
        for (uint16 i = 0; i < maxLands; i++) {
            lands[i] = Land(lowestPrice, 0, 0, address(0));
        }
    }

    function emergencyWithdraw() public onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) {
            revert TransferFailed(address(this), msg.sender, address(this).balance);
        }
    }

    function withdrawPrizePool() public onlyOwner {
        (bool success, ) = msg.sender.call{value: _systemPool.prize}("");
        if (!success) {
            revert TransferFailed(address(this), msg.sender, _systemPool.prize);
        }
        _systemPool.prize = 0;
    }

    function withdrawTreasuryPool() public onlyOwner {
        (bool success, ) = msg.sender.call{value: _systemPool.treasury}("");
        if (!success) {
            revert TransferFailed(address(this), msg.sender, _systemPool.treasury);
        }
        _systemPool.treasury = 0;
    }

    function withdrawTeamPool() public onlyOwner {
        (bool success, ) = msg.sender.call{value: _systemPool.team}("");
        if (!success) {
            revert TransferFailed(address(this), msg.sender, _systemPool.team);
        }
        _systemPool.team = 0;
    }

    function withdrawFMP() public onlyOwner {
        fmp.transfer(msg.sender, fmp.balanceOf(address(this)));
    }

    // modifiers
    modifier playerExisted() {
        require(players[msg.sender].exist, "Player does not exist");
        _;
    }

    // view functions
    function allOwners() public view returns (address[] memory, uint16) {
        address[] memory owners = new address[](maxLands);
        uint16 count = 0;
        for (uint16 i = 0; i < maxLands; i++) {
            Land memory land = lands[i];
            if (land.owner != address(0)) {
                owners[i] = land.owner;
                count++;
            }
        }
        return (owners, count);
    }

    function getAllLandPrice(uint16 start, uint16 end) public view returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](end - start);
        for (uint16 i = start; i < end; i++) {
            prices[i] = getLandPrice(i);
        }
        return prices;
    }

    function getPlayerOwnedLandIDs(address player) public view returns (uint16[] memory) {
        uint16 count = 0;
        for (uint16 i = 0; i < maxLands; i++) {
            if (lands[i].owner == player) {
                count++;
            }
        }
        uint16[] memory landIDs = new uint16[](count);
        
        count = 0;
        for (uint16 i = 0; i < maxLands; i++) {
            if (lands[i].owner == player) {
                landIDs[count] = i;
                count++;
            }
        }
        return landIDs;
    }

    function getLandPrice(uint16 landId) public view returns (uint256) {
        // Retrieve the land record from storage
        Land storage land = lands[landId];

        // If the land has never been bought (lastBoughtAt == 0), return the current price directly
        if (land.lastBoughtAt == 0) {
            return land.price; 
        }
        
        // Calculate the number of times the price should decrease based on the time since last purchase
        uint256 decreaseTimes = (block.timestamp - land.lastBoughtAt) / decreaseInterval;
        
        // Calculate the total decrease amount based on the decrease rate and the number of decrease intervals passed
        uint256 decreaseAmount = land.price * decreaseRate / 100 * decreaseTimes;
        
        // Calculate the new price by subtracting the decrease amount from the current price
        // Ensure the new price does not fall below the minimum allowed price (lowestPrice)
        uint256 newPrice = land.price > decreaseAmount ? land.price - decreaseAmount : lowestPrice;
        
        // Return the final adjusted price, ensuring it's not less than the lowestPrice
        return newPrice < lowestPrice ? lowestPrice : newPrice;
    }


    function getPlayer(address player) public view returns (uint16, uint16, uint256) {
        Player storage p = players[player];
        uint16 pos = p.position;
        if (p.exist == false) {
            pos = _getPlayerInitPos(msg.sender);
        }
        return (pos, p.landAmount, p.rewardDebt);
    }

    function getPlayerProps(address player) public view returns (uint256[] memory) {
        uint256[] memory props = new uint256[](8);
        Player storage p = players[player];
        props[0] = p.props[Props.OddDice];
        props[1] = p.props[Props.EvenDice];
        props[2] = p.props[Props.LowDice];
        props[3] = p.props[Props.HighDice];
        props[4] = p.props[Props.LandFlipper];
        props[5] = p.props[Props.Ticket];
        props[6] = p.props[Props.LotteryTicket];
        props[7] = p.props[Props.WorldWideTravel];
        return props;
    }

    function getPool() public view returns (uint256, uint256) {
        return (_pool.lastRewardBlock, _pool.accRewardPerShare);
    }

    function getLand(uint16 landId) public view returns (uint256, uint256, address) {
        Land storage land = lands[landId];
        return (land.price, land.lastBoughtAt, land.owner);
    }

    function getPropPricesETH() public view returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](6);
        prices[0] = propPrices[Props.OddDice][PropPaymentType.ETH];
        prices[1] = propPrices[Props.EvenDice][PropPaymentType.ETH];
        prices[2] = propPrices[Props.LowDice][PropPaymentType.ETH];
        prices[3] = propPrices[Props.HighDice][PropPaymentType.ETH];
        prices[4] = propPrices[Props.LandFlipper][PropPaymentType.ETH];
        prices[5] = propPrices[Props.WorldWideTravel][PropPaymentType.ETH];
        return prices;
    }

    function getPropPricesFMP() public view returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](6);
        prices[0] = propPrices[Props.OddDice][PropPaymentType.FMP];
        prices[1] = propPrices[Props.EvenDice][PropPaymentType.FMP];
        prices[2] = propPrices[Props.LowDice][PropPaymentType.FMP];
        prices[3] = propPrices[Props.HighDice][PropPaymentType.FMP];
        prices[4] = propPrices[Props.LandFlipper][PropPaymentType.FMP];
        prices[5] = propPrices[Props.WorldWideTravel][PropPaymentType.FMP];
        return prices;
    }

    function getSystemPool() public view returns (uint256, uint256, uint256) {
        return (_systemPool.prize, _systemPool.treasury, _systemPool.team);
    }

    // get pending reward and reward debt for player
    function getPendingReward(address player) public view returns (uint256, uint256) {
        Player storage p = players[player];
        uint256 pending = p.landAmount * _pool.accRewardPerShare - p.rewardDebt;
        return (pending, p.rewardDebt);
    }
    
    // Function to generate a pseudo-random number between 1 and 6
    // `numberType` parameter controls the type of number generated
    function getRandomNumber(NumberType numberType) public view returns (uint16) {
        uint16 random = uint16(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 6 + 1);

        if (numberType == NumberType.Odd) {
            // Ensure the number is odd, adjust if it's even
            if (random % 2 == 0) {
                return random == 6 ? 1 : random + 1;
            }
        } else if (numberType == NumberType.Even) {
            // Ensure the number is even, adjust if it's odd
            if (random % 2 != 0) {
                return random == 1 ? 6 : random - 1;
            }
        } else if (numberType == NumberType.Low) {
            // Limit to 1-3 range
            return random > 3 ? random - 3 : random;
        } else if (numberType == NumberType.High) {
            // Limit to 4-6 range
            return random <= 3 ? random + 3 : random;
        }

        // Return any number between 1 and 6
        return random;
    }

    // fallback() & receive() functions to receive ETH
    fallback() external payable {}
    receive() external payable {}

    // IBlast functions
    function claimYield(address recipient, uint256 amount) external {
        //This function is public meaning anyone can claim the yield
        blast.claimYield(address(this), recipient, amount);
    }

    function claimAllYield(address recipient) external {
        //This function is public meaning anyone can claim the yield
        blast.claimAllYield(address(this), recipient);
    }
} 