// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IAssetAdministrator {
    enum ProposalType {
        SetAsset,
        RemoveAsset,
        SetupMultiSig
    }

    struct SignerInfo {
        bool isValid;
        uint256 weight;
    }

    // Events
    event MultiSigSetup(address[] signers, uint256[] weights, uint256 threshold);
    event ProposalCreated(uint256 indexed proposalId, ProposalType proposalType);
    event ProposalApproved(uint256 indexed proposalId, address approver);
    event ProposalExecuted(uint256 indexed proposalId);

    // Errors
    error ZeroAddressDetected();
    error NotValidSigner();
    error InvalidThreshold();
    error InvalidWeight();
    error InvalidInput();
    error DuplicateSigner();
    error ProposalNotFound();
    error ProposalCompleted();
    error AlreadyApproved();
    error NotCurrentAdmin();
    error InvalidProposalHash();

    // View functions
    function getSigners() external view returns (address[] memory);
    function signerInfo(address signer) external view returns (SignerInfo memory);
    function threshold() external view returns (uint256);
    function totalWeight() external view returns (uint256);
    function numValidSigners() external view returns (uint256);

    function getProposal(uint256 _proposalId) external view returns (
        ProposalType proposalType,
        uint256 assetId,
        address assetContract,
        uint256 proposalTime,
        uint256 totalApprovalWeight,
        bool isCompleted,
        address[] memory approvers,
        address[] memory proposedSigners,
        uint256[] memory proposedWeights,
        uint256 proposedThreshold
    );

    // Proposal creation functions
    function proposeSetupMultiSig(
        address[] memory _signers,
        uint256[] memory _weights,
        uint256 _threshold
    ) external;
    
    function proposeSetAsset(uint256 assetId, address assetContract) external;
    function proposeRemoveAsset(uint256 assetId) external;

    // Proposal approval function
    function approveProposal(uint256 _proposalId) external;
}