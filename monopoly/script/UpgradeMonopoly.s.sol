// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Monopoly} from "../src/Monopoly.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeMonopoly is Script {
    function run() external returns (address) {
        vm.startBroadcast();
        Monopoly newMonopoly = new Monopoly();
        address proxy = upgradeMonopoly(
            address(0xD2f84B732D73Ab6df566E3BC34BbA5bA3b519d17),
            address(newMonopoly)
            );
        vm.stopBroadcast();
        return proxy;
    }

    function upgradeMonopoly(
        address proxyAddr,
        address newImplementation
    ) public returns (address) {
        Monopoly proxy = Monopoly(payable(proxyAddr));
        proxy.upgradeToAndCall(address(newImplementation), "");
        return address(proxy);
    }

}