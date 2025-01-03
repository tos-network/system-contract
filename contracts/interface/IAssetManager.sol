// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IAssetManager {
    // Events
    event AssetSet(
        uint256 indexed assetId,
        address indexed oldContract,
        address indexed newContract
    );

    // View functions
    function getAssetContract(uint256 assetId) external view returns (address);
    function owner() external view returns (address);

    // State-changing functions
    function setAsset(uint256 assetId, address assetContract) external;
    function removeAsset(uint256 assetId) external;
}