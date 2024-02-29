// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract FomopolyToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
    mapping(bytes32 => bool) public mintedTxHashes;
    
    event BridgeMinted(
        bytes32 indexed flowTxHash,
        string flowFrom,
        address indexed to,
        uint256 amount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __ERC20_init("Fomopoly", "FMP");
        __ERC20Burnable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("Fomopoly");
        __UUPSUpgradeable_init();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function bridgeMint(
        bytes32 flowTxHash, // bridge tx hash on Flow
        string calldata flowFrom, // from address on Flow with out 0x prefix
        address to,  // to address on EVM
        uint256 amount // amount of tokens
    ) public onlyOwner {
        require(!mintedTxHashes[flowTxHash], "FMP: tx hash already minted");
        mintedTxHashes[flowTxHash] = true;
        _mint(to, amount);
        emit BridgeMinted(flowTxHash, flowFrom, to, amount);
    }

    // TODO: remove this function on production
    function internalTestMint() public {
        // mint 10000 * decimals() tokens to the sender
        _mint(msg.sender, 10000 * 10**decimals());
    } 

    function isTxMinted(bytes32 txHash) public view returns (bool) {
        return mintedTxHashes[txHash];
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}
