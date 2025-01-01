// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../contracts/AssetManager.sol";
import "../contracts/System.sol";

contract AssetManagerTest is Test, System {
    AssetManager public assetManager;
    address public owner;
    address public user;
    
    // Test asset details
    uint256 constant ASSET_ID_1 = 1;
    uint256 constant ASSET_ID_2 = 2;
    address constant MOCK_ASSET_1 = address(0x1);
    address constant MOCK_ASSET_2 = address(0x2);

    event AssetSet(
        uint256 indexed assetId,
        address indexed oldContract,
        address indexed newContract
    );

    function setUp() public {
        // Deploy AssetManager
        assetManager = new AssetManager();
        
        // Setup test accounts
        owner = ASSET_ADMINOR_ADDR;
        user = makeAddr("user");
        
        // Label addresses for better trace output
        vm.label(address(assetManager), "AssetManager");
        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(MOCK_ASSET_1, "MockAsset1");
        vm.label(MOCK_ASSET_2, "MockAsset2");
    }

    // Test initial state
    function test_InitialState() public {
        assertEq(assetManager.owner(), ASSET_ADMINOR_ADDR);
        assertEq(assetManager.getAssetContract(ASSET_ID_1), address(0));
    }

    // Test setAsset function
    function test_SetAsset() public {
        vm.startPrank(ASSET_ADMINOR_ADDR);
        
        vm.expectEmit(true, true, true, true);
        emit AssetSet(ASSET_ID_1, address(0), MOCK_ASSET_1);
        
        assetManager.setAsset(ASSET_ID_1, MOCK_ASSET_1);
        assertEq(assetManager.getAssetContract(ASSET_ID_1), MOCK_ASSET_1);
        
        vm.stopPrank();
    }

    // Test setAsset with zero address
    function test_SetAsset_ZeroAddress() public {
        vm.startPrank(ASSET_ADMINOR_ADDR);
        
        vm.expectRevert("Zero address not allowed");
        assetManager.setAsset(ASSET_ID_1, address(0));
        
        vm.stopPrank();
    }

    // Test setAsset unauthorized access
    function test_SetAsset_Unauthorized() public {
        vm.startPrank(user);
        
        vm.expectRevert("Not authorized");
        assetManager.setAsset(ASSET_ID_1, MOCK_ASSET_1);
        
        vm.stopPrank();
    }

    // Test updating existing asset
    function test_UpdateAsset() public {
        vm.startPrank(ASSET_ADMINOR_ADDR);
        
        // Set initial asset
        assetManager.setAsset(ASSET_ID_1, MOCK_ASSET_1);
        
        // Update asset
        vm.expectEmit(true, true, true, true);
        emit AssetSet(ASSET_ID_1, MOCK_ASSET_1, MOCK_ASSET_2);
        
        assetManager.setAsset(ASSET_ID_1, MOCK_ASSET_2);
        assertEq(assetManager.getAssetContract(ASSET_ID_1), MOCK_ASSET_2);
        
        vm.stopPrank();
    }

    // Test removeAsset function
    function test_RemoveAsset() public {
        vm.startPrank(ASSET_ADMINOR_ADDR);
        
        // First set an asset
        assetManager.setAsset(ASSET_ID_1, MOCK_ASSET_1);
        
        // Then remove it
        vm.expectEmit(true, true, true, true);
        emit AssetSet(ASSET_ID_1, MOCK_ASSET_1, address(0));
        
        assetManager.removeAsset(ASSET_ID_1);
        assertEq(assetManager.getAssetContract(ASSET_ID_1), address(0));
        
        vm.stopPrank();
    }

    // Test removeAsset when asset doesn't exist
    function test_RemoveAsset_NonExistent() public {
        vm.startPrank(ASSET_ADMINOR_ADDR);
        
        // Should not emit any event
        assetManager.removeAsset(ASSET_ID_1);
        assertEq(assetManager.getAssetContract(ASSET_ID_1), address(0));
        
        vm.stopPrank();
    }

    // Test removeAsset unauthorized access
    function test_RemoveAsset_Unauthorized() public {
        vm.startPrank(user);
        
        vm.expectRevert("Not authorized");
        assetManager.removeAsset(ASSET_ID_1);
        
        vm.stopPrank();
    }

    // Test multiple assets
    function test_MultipleAssets() public {
        vm.startPrank(ASSET_ADMINOR_ADDR);
        
        // Set multiple assets
        assetManager.setAsset(ASSET_ID_1, MOCK_ASSET_1);
        assetManager.setAsset(ASSET_ID_2, MOCK_ASSET_2);
        
        // Verify both assets
        assertEq(assetManager.getAssetContract(ASSET_ID_1), MOCK_ASSET_1);
        assertEq(assetManager.getAssetContract(ASSET_ID_2), MOCK_ASSET_2);
        
        // Remove one asset
        assetManager.removeAsset(ASSET_ID_1);
        
        // Verify state
        assertEq(assetManager.getAssetContract(ASSET_ID_1), address(0));
        assertEq(assetManager.getAssetContract(ASSET_ID_2), MOCK_ASSET_2);
        
        vm.stopPrank();
    }
}