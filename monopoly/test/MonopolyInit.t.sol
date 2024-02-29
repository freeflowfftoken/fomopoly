// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Monopoly, Player, Props, PropPaymentType} from "../src/Monopoly.sol";
import {FomopolyToken} from "../src/FMP.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./mocks/MockBlast.sol";

contract MonopolyTest is Test {
    Monopoly public monopoly;
    FomopolyToken public fmp;
    MockBlast public blast;
    address public owner;

    function testInit() public {
        owner = msg.sender;
        vm.startPrank(owner);

        // deploy blast implmentation
        blast = new MockBlast();

        // deploy fmp implmentation
        fmp = new FomopolyToken();

        // init fmp
        ERC1967Proxy fmpProxy = new ERC1967Proxy(address(fmp), "");
        fmp = FomopolyToken(address(fmpProxy));
        fmp.initialize(owner);

        // deploy monopoly implmentation
        monopoly = new Monopoly();

        // init monopoly
        ERC1967Proxy monopolyProxy = new ERC1967Proxy(address(monopoly), "");
        monopoly = Monopoly(payable(address(monopolyProxy)));
        monopoly.initialize(owner, address(fmp), address(blast));

        (bool success, bytes memory result) = address(fmpProxy).call(abi.encodeWithSignature("owner()"));
        assertEq(success, true);
        address fmpOwner;
        assembly {
            fmpOwner := mload(add(result, 0x20))
        }

        assertEq(fmpOwner == owner, true);

        (success, result) = address(monopolyProxy).call(abi.encodeWithSignature("owner()"));
        assertEq(success, true);
        address monopolyOwner;
        assembly {
            monopolyOwner := mload(add(result, 0x20))
        }

        assertEq(monopolyOwner == owner, true);

        vm.stopPrank();
    }

}
