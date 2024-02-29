// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Monopoly} from "../src/Monopoly.sol";
import {FomopolyToken} from "../src/FMP.sol";

contract DeployMonopoly is Script {
    function run() external {
        vm.startBroadcast();
        address fmp = deployFMPToken();
        address monopoly = deployMonopoly();
        
        initFMPToken(fmp);
        address blast = address(0x4300000000000000000000000000000000000002);
        initMonopoly(monopoly, fmp, blast);

        vm.stopBroadcast();
    }

    function deployMonopoly() public returns (address payable) {
        Monopoly monopoly = new Monopoly();
        // console2.log("deployMonopoly...");
        // console2.log("Monopoly: ", address(monopoly));
        // console2.log("this: ", address(this));
        // console2.log("msg.sender: ", msg.sender);
        ERC1967Proxy proxy = new ERC1967Proxy(address(monopoly), "");
        return payable(address(proxy));
    }

    function initMonopoly(
        address proxy,
        address fmp,
        address blast
    ) public {
        Monopoly m = Monopoly(payable(proxy));
        // console2.log("initMonopoly msg.sender: ", msg.sender);
        m.initialize(msg.sender, fmp, blast);
    }

    function deployFMPToken() public returns (address) {
        FomopolyToken fmp = new FomopolyToken();
        // console2.log("deployFMPToken...");
        // console2.log("FomopolyToken: ", address(fmp));
        // console2.log("this: ", address(this));
        // console2.log("msg.sender: ", msg.sender);
        ERC1967Proxy proxy = new ERC1967Proxy(address(fmp), "");
        return address(proxy);
    }

    function initFMPToken(
        address proxy
    ) public {
        FomopolyToken fmp = FomopolyToken(proxy);
        // console2.log("initFMPToken msg.sender: ", msg.sender);
        fmp.initialize(msg.sender);
    }
}