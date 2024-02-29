// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FomopolyToken} from "../src/FMP.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeFMP is Script {
    function run() external returns (address) {
        vm.startBroadcast();
        FomopolyToken newFMP = new FomopolyToken();
        address proxy = upgradeFMP(
            address(0x64C593bA68A03750DeCee015066e104236BF9346),
            address(newFMP)
            );
        vm.stopBroadcast();
        return proxy;
    }

    function upgradeFMP(
        address proxyAddr,
        address newImplementation
    ) public returns (address) {
        FomopolyToken proxy = FomopolyToken(payable(proxyAddr));
        proxy.upgradeToAndCall(address(newImplementation), "");
        return address(proxy);
    }

}