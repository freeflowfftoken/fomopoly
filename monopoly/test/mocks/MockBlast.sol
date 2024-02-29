// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBlast, GasMode, YieldMode} from "../../src/IBlast/IBlast.sol";

contract MockBlast is IBlast {
    function configureContract(address contractAddress, YieldMode _yield, GasMode gasMode, address governor) external override {
        // Mock implementation - do nothing
    }

    function configure(YieldMode _yield, GasMode gasMode, address governor) external override {
        // Mock implementation - do nothing
    }

    function configureClaimableYield() external override {
        // Mock implementation - do nothing
    }

    function configureClaimableYieldOnBehalf(address contractAddress) external override {
        // Mock implementation - do nothing
    }

    function configureAutomaticYield() external override {
        // Mock implementation - do nothing
    }

    function configureAutomaticYieldOnBehalf(address contractAddress) external override {
        // Mock implementation - do nothing
    }

    function configureVoidYield() external override {
        // Mock implementation - do nothing
    }

    function configureVoidYieldOnBehalf(address contractAddress) external override {
        // Mock implementation - do nothing
    }

    function configureClaimableGas() external override {
        // Mock implementation - do nothing
    }

    function configureClaimableGasOnBehalf(address contractAddress) external override {
        // Mock implementation - do nothing
    }

    function configureVoidGas() external override {
        // Mock implementation - do nothing
    }

    function configureVoidGasOnBehalf(address contractAddress) external override {
        // Mock implementation - do nothing
    }

    function configureGovernor(address _governor) external override {
        // Mock implementation - do nothing
    }

    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external override {
        // Mock implementation - do nothing
    }

    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external override returns (uint256) {
        // Mock implementation - always return 0
        return 0;
    }

    function claimAllYield(address contractAddress, address recipientOfYield) external override returns (uint256) {
        // Mock implementation - always return 0
        return 0;
    }

    function claimAllGas(address contractAddress, address recipientOfGas) external override returns (uint256) {
        // Mock implementation - always return 0
        return 0;
    }

    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 minClaimRateBips) external override returns (uint256) {
        // Mock implementation - always return 0
        return 0;
    }

    function claimMaxGas(address contractAddress, address recipientOfGas) external override returns (uint256) {
        // Mock implementation - always return 0
        return 0;
    }

    function claimGas(address contractAddress, address recipientOfGas, uint256 gasToClaim, uint256 gasSecondsToConsume) external override returns (uint256) {
        // Mock implementation - always return 0
        return 0;
    }

    function readClaimableYield(address contractAddress) external view override returns (uint256) {
        // Mock implementation - always return 0
        return 0;
    }

    function readYieldConfiguration(address contractAddress) external view override returns (uint8) {
        // Mock implementation - return a default value
        return 0;
    }

    function readGasParams(address contractAddress) external view override returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode gasMode) {
        // Mock implementation - return default values
        return (0, 0, 0, GasMode(0));
    }
}
