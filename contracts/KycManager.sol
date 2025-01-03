// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./interface/IKycManager.sol";
import "./System.sol";

enum ContractState {
    Active,
    Paused
}

contract KycManager is IKycManager, System {
    struct RegionData {
        bool exists;
        bool paused;
        mapping(address user => bool) admins;
        mapping(address user => bool) ops;
    }

    mapping(address user => uint256) public kycLevel;
    mapping(uint256 regionId => RegionData) public regions;

    ContractState public contractState;
    uint256 private constant MAX_KYC_LEVEL = 255;
    address public immutable override globalAdmin = KYCLE_ADMINOR_ADDR;  

    event RegionAdd(uint256 indexed regionId);
    event RegionDel(uint256 indexed regionId);
    event AdminAdd(uint256 indexed regionId, address indexed admin);
    event AdminDel(uint256 indexed regionId, address indexed admin);
    event OpAdd(uint256 indexed regionId, address indexed op);
    event OpDel(uint256 indexed regionId, address indexed op);

    event KYCUpdate(
        address indexed user,
        uint256 oldLevel,
        uint256 newLevel,
        uint256 indexed regionId,
        address indexed operator
    );

    event RegionPaused(uint256 indexed regionId, bool paused);

    event RegionStateChanged(uint256 indexed regionId, bool paused);
    event OperatorStateChanged(uint256 indexed regionId, address indexed operator, bool added);
    event ContractStateChanged(ContractState newState);

    constructor() payable {
    }

    modifier onlyGlobal() {
        require(msg.sender == globalAdmin, "NotGlobal");
        _;
    }

    modifier validR(uint256 regionId) {
        require(regions[regionId].exists, "BadRegion");
        _;
    }

    modifier onlyAdmOrGlobal(uint256 regionId) {
        RegionData storage region = regions[regionId];
        require(region.admins[msg.sender] || msg.sender == globalAdmin, "NoPerm");
        _;
    }

    modifier whenNotPaused() {
        require(contractState == ContractState.Active, "Paused");
        _;
    }

    modifier whenRegionNotPaused(uint256 regionId) {
        require(!regions[regionId].paused, "RegionPaused");
        _;
    }

    function addRegionId(uint256 regionId) external override onlyGlobal {
        RegionData storage region = regions[regionId];
        if (!region.exists) {
            region.exists = true;
            emit RegionAdd(regionId);
        }
    }

    function removeRegionId(uint256 regionId) external override onlyGlobal {
        RegionData storage region = regions[regionId];
        require(region.exists, "NoR");
        region.exists = false;
        emit RegionDel(regionId);
    }

    function addRegionAdmin(uint256 regionId, address admin)
        external
        override
        onlyGlobal
        validR(regionId)
    {
        require(admin != address(0), "Zero");
        RegionData storage region = regions[regionId];
        if (!region.admins[admin]) {
            region.admins[admin] = true;
            emit AdminAdd(regionId, admin);
        }
    }

    function removeRegionAdmin(uint256 regionId, address admin)
        external
        override
        onlyGlobal
        validR(regionId)
    {
        RegionData storage region = regions[regionId];
        if (region.admins[admin]) {
            region.admins[admin] = false;
            emit AdminDel(regionId, admin);
        }
    }

    function toggleContractState() external override onlyGlobal {
        ContractState newState = contractState == ContractState.Active 
            ? ContractState.Paused 
            : ContractState.Active;
        contractState = newState;
        emit ContractStateChanged(newState);
    }

    function addRegionOperator(uint256 regionId, address op)
        external
        validR(regionId)
        onlyAdmOrGlobal(regionId)
    {
        require(op != address(0), "ZeroOp");
        RegionData storage region = regions[regionId];
        if (!region.ops[op]) {
            region.ops[op] = true;
            emit OpAdd(regionId, op);
        }
    }

    function removeRegionOperator(uint256 regionId, address op)
        external
        validR(regionId)
        onlyAdmOrGlobal(regionId)
    {
        RegionData storage region = regions[regionId];
        if (region.ops[op]) {
            region.ops[op] = false;
            emit OpDel(regionId, op);
        }
    }

    function setKYCLevel(
        address user,
        uint256 newLevel,
        uint256 regionId
    )
        external
        validR(regionId)
        whenNotPaused
        whenRegionNotPaused(regionId)
    {
        require(newLevel < MAX_KYC_LEVEL, "InvalidLevel");
        RegionData storage region = regions[regionId];
        require(region.ops[msg.sender], "NotOp");
        
        uint256 oldLevel = kycLevel[user];
        if (oldLevel != newLevel) {
            kycLevel[user] = newLevel;
            emit KYCUpdate(user, oldLevel, newLevel, regionId, msg.sender);
        }
    }

    function toggleRegionState(uint256 regionId) 
        external 
        validR(regionId)
        onlyAdmOrGlobal(regionId) 
    {
        RegionData storage region = regions[regionId];
        bool newState = !region.paused;
        region.paused = newState;
        emit RegionStateChanged(regionId, newState);
    }

    function isRegionAdmin(uint256 regionId, address admin) 
        external 
        view 
        returns (bool) 
    {
        return regions[regionId].admins[admin];
    }

    function isRegionOperator(uint256 regionId, address operator) 
        external 
        view 
        returns (bool) 
    {
        return regions[regionId].ops[operator];
    }

    function isRegionPaused(uint256 regionId) 
        external 
        view 
        returns (bool) 
    {
        return regions[regionId].paused;
    }
}