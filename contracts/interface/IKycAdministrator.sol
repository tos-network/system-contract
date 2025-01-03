// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IKycAdministrator {
    enum ProposalType {
        AddRegion,
        RemoveRegion,
        AddRegionAdmin,
        RemoveRegionAdmin,
        ToggleState,
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
    event ProposalCancelled(uint256 indexed proposalId);

    // Errors
    error ZeroAddressDetected();
    error NotValidSigner();
    error InvalidThreshold();
    error InvalidWeight();
    error InvalidInput();
    error DuplicateSigner();
    error ProposalNotFound();
    error ProposalCompleted();
    error ProposalExpired();
    error AlreadyApproved();
    error NotCurrentAdmin();
    error InvalidProposalHash();
    error NotProposalCreator();
    error InvalidProposalState();
    error NotAuthorized();

    // View functions
    function getSigners() external view returns (address[] memory);
    function signerInfo(address signer) external view returns (SignerInfo memory);
    function threshold() external view returns (uint256);
    function totalWeight() external view returns (uint256);
    function numValidSigners() external view returns (uint256);
    function proposalExpiration() external view returns (uint256);

    function getProposal(uint256 _proposalId) external view returns (
        ProposalType proposalType,
        address proposedAdmin,
        uint256 regionId,
        address regionAdmin,
        uint256 proposalTime,
        uint256 totalApprovalWeight,
        bool isCompleted,
        bool isCancelled,
        address creator,
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
    
    function proposeAddRegion(uint256 _regionId) external;
    function proposeRemoveRegion(uint256 _regionId) external;
    function proposeAddRegionAdmin(uint256 _regionId, address _admin) external;
    function proposeRemoveRegionAdmin(uint256 _regionId, address _admin) external;
    function proposeToggleState() external;

    // Proposal management functions
    function approveProposal(uint256 _proposalId) external;
    function cancelProposal(uint256 _proposalId) external;
}