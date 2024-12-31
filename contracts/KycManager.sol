// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

enum ContractState {
    Active,
    Paused
}

contract KYCManager {
    struct RegionData {
        bool exists;
        bool paused;
        mapping(address user => bool) admins;
        mapping(address user => bool) ops;
    }

    mapping(uint256 regionId => RegionData) public regions;
    mapping(address user => uint8) public kycLevel;

    address public globalAdmin;

    ContractState public contractState;
    uint8 public constant MAX_KYC_LEVEL = 255;

    event RegionAdd(uint256 indexed regionId);
    event RegionDel(uint256 indexed regionId);
    event AdminAdd(uint256 indexed regionId, address indexed admin);
    event AdminDel(uint256 indexed regionId, address indexed admin);
    event OpAdd(uint256 indexed regionId, address indexed op);
    event OpDel(uint256 indexed regionId, address indexed op);

    event KYCUpdate(
        address indexed user,
        uint8 oldLevel,
        uint8 newLevel,
        uint256 indexed regionId,
        address indexed operator
    );

    event GlobalAdminXfer(address indexed oldAdmin, address indexed newAdmin);

    event RegionPaused(uint256 indexed regionId, bool paused);

    constructor() payable {
        globalAdmin = msg.sender;
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
        // read region data once
        RegionData storage region = regions[regionId];
        bool isAdm = region.admins[msg.sender];
        bool isGlobal = (msg.sender == globalAdmin);
        require(isAdm || isGlobal, "NoPerm");
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

    // global admin fns
    function addRegionId(uint256 regionId) external onlyGlobal {
        RegionData storage region = regions[regionId];
        if (!region.exists) {
            region.exists = true;
            emit RegionAdd(regionId);
        }
    }

    // global admin fns
    function removeRegionId(uint256 regionId) external onlyGlobal {
        RegionData storage region = regions[regionId];
        require(region.exists, "NoR");
        region.exists = false;
        emit RegionDel(regionId);
    }


    // global admin fns
    function addRegionAdmin(uint256 regionId, address admin)
        external
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

    // global admin fns
    function removeRegionAdmin(uint256 regionId, address admin)
        external
        onlyGlobal
        validR(regionId)
    {
        RegionData storage region = regions[regionId];
        if (region.admins[admin]) {
            region.admins[admin] = false;
            emit AdminDel(regionId, admin);
        }
    }

    // global admin fns
    function transferGlobalAdmin(address newAdmin) external onlyGlobal {
        require(newAdmin != address(0), "ZeroAdmin");
        address old = globalAdmin;
        if (newAdmin != old) {
            globalAdmin = newAdmin;
            emit GlobalAdminXfer(old, newAdmin);
        }
    }

    // global admin fns
    function toggleContractState() external onlyGlobal {
        contractState = contractState == ContractState.Active 
            ? ContractState.Paused 
            : ContractState.Active;
    }

    // region admin fns
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

    // region admin fns
    function isRegionAdmin(uint256 regionId, address admin) 
        external 
        view 
        returns (bool) 
    {
        return regions[regionId].admins[admin];
    }
  
    // region admin fns
    function toggleRegionState(uint256 regionId) 
        external 
        validR(regionId)
        onlyAdmOrGlobal(regionId) 
    {
        RegionData storage region = regions[regionId];
        region.paused = !region.paused;
        emit RegionPaused(regionId, region.paused);
    }

    // region admin fns
    function isRegionPaused(uint256 regionId) 
        external 
        view 
        returns (bool) 
    {
        return regions[regionId].paused;
    }

    // region operator fns
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

    // region operator fn
    function setKYCLevel(
        address user,
        uint8 newLevel,
        uint256 regionId
    )
        external
        validR(regionId)
        whenNotPaused
        whenRegionNotPaused(regionId)
    {
        require(newLevel <= MAX_KYC_LEVEL, "InvalidLevel");
        RegionData storage region = regions[regionId];
        require(region.ops[msg.sender], "NotOp");
        uint8 old = kycLevel[user];
        if (old != newLevel) {
            kycLevel[user] = newLevel;
            emit KYCUpdate(user, old, newLevel, regionId, msg.sender);
        }
    }
  
    // region operator fns
    function isRegionOperator(uint256 regionId, address operator) 
        external 
        view 
        returns (bool) 
    {
        return regions[regionId].ops[operator];
    }
}
