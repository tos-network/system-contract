// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

contract System {

    bool public alreadyInit;

    address public constant ASSET_ADMINOR_ADDR = 0x0000000000000000000000000000000000001000;
    address public constant ASSET_MANAGER_ADDR = 0x0000000000000000000000000000000000001001;
    
    address public constant KYCLE_ADMINOR_ADDR = 0x0000000000000000000000000000000000001002;
    address public constant KYCLE_MANAGER_ADDR = 0x0000000000000000000000000000000000001003;

    address public constant OWNER_ADMINOR_ADDR = 0x0000000000000000000000000000000000001004;
    address public constant OWNER_ACCOUNT_ADDR = 0x0000000000000000000000000000000000001005;

    address public constant WTOS_CONTRACT_ADDR = 0x0000000000000000000000000000000000001006;

    address public constant JAVA_CONTRACT_ADDR = 0x0000000000000000000000000000000000001007;

    modifier onlyNotInit() {
        require(!alreadyInit, "the contract already init");
        _;
    }

    modifier onlyInit() {
        require(alreadyInit, "the contract not init yet");
        _;
    }

}