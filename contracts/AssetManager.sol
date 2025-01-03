// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./interface/IAssetManager.sol";
import "./System.sol";
/**
 * @title AssetManager
 * @notice This contract manages a mapping between asset IDs and their corresponding
 *         stablecoin contract addresses on the TOS network.
 */
contract AssetManager is IAssetManager, System {
    /**
     * @dev Mapping of "assetId" => "contract address".
     */
    mapping(uint256 => address) public assetContracts;

    /**
     * @notice The address of the contract owner (likely a multisig).
     *         Only this owner can add or remove assets.
     */
    address public owner = ASSET_ADMINOR_ADDR;

    /**
     * @dev Constructor. 
     */
    constructor() payable {
    }

    /**
     * @dev Restricts execution to only the current owner.
     *      Useful if your owner is a multisig wallet on TOS network for secure admin operations.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /**
     * @notice Registers or updates the stablecoin contract address for a specific asset ID.
     * @dev The asset ID can represent TOS native coin, or any stablecoin on TOS network.
     * @param assetId The unique ID representing the asset on TOS network.
     * @param assetContract The contract address linked to the asset (cannot be zero).
     *
     * Emits an {AssetSet} event indicating the old and new addresses.
     */
    function setAsset(uint256 assetId, address assetContract) external onlyOwner {
        require(assetContract != address(0), "Zero address not allowed");

        address oldAddress = assetContracts[assetId];
        assetContracts[assetId] = assetContract;

        emit AssetSet(assetId, oldAddress, assetContract);
    }

    /**
     * @notice Removes an asset by setting its contract address to address(0).
     * @dev This effectively unlinks the asset ID from any stablecoin contract on TOS network.
     *      If the asset doesn't exist (address is already 0), the function will return silently.
     * @param assetId The ID of the asset to remove.
     *
     * Emits an {AssetSet} event with the old address and a new address of zero if the asset existed.
     */
    function removeAsset(uint256 assetId) external onlyOwner {
        address oldAddress = assetContracts[assetId];
        if (oldAddress != address(0)) {
            assetContracts[assetId] = address(0);
            emit AssetSet(assetId, oldAddress, address(0));
        }
    }

    /**
     * @notice Retrieves the contract address associated with a given asset ID.
     * @dev Returns address(0) if asset not set or has been removed.
     * @param assetId The ID of the asset.
     * @return The stablecoin contract address mapped to this asset ID.
     */
    function getAssetContract(uint256 assetId) external view returns (address) {
        return assetContracts[assetId];
    }
}
