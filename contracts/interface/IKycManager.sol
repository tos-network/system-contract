// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IKycManager {
    function globalAdmin() external view returns (address);
    function addRegionId(uint256 regionId) external;
    function removeRegionId(uint256 regionId) external;
    function addRegionAdmin(uint256 regionId, address admin) external;
    function removeRegionAdmin(uint256 regionId, address admin) external;
    function toggleContractState() external;
}