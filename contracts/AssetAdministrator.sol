// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./interface/IAssetManager.sol";
import "./interface/IAssetAdministrator.sol";
import "./System.sol";

contract AssetAdministrator is IAssetAdministrator, System {
    // Add domain separator for multi-sig proposals
    bytes32 public constant DOMAIN_SEPARATOR = keccak256("AssetAdministrator_V1");
    
    // State variables for multi-sig management
    address[] public signers;
    uint256 public threshold;
    uint256 public numValidSigners;
    uint256 public totalWeight;
    uint256 public proposalId;

    // Proposal structure for all administrative actions
    struct Proposal {
        uint256 id;
        ProposalType proposalType;
        uint256 assetId;          // for asset operations
        address assetContract;     // for asset operations
        uint256 proposalTime;
        uint256 totalApprovalWeight;
        bool isCompleted;
        address[] approvers;
        // Fields for multi-sig setup
        address[] proposedSigners;
        uint256[] proposedWeights;
        uint256 proposedThreshold;
    }

    // Mappings for contract state management
    mapping(address => SignerInfo) internal _signerInfo;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => bytes32) private proposalHashes;
    mapping(address => mapping(uint256 => bool)) public hasSignedProposal;
    
    // Constant address for Asset Manager contract
    address public constant assetManager = ASSET_MANAGER_ADDR;   

    // Initialize function replaces constructor
    function initialize(address initialAdmin) external onlyNotInit {
        require(initialAdmin != address(0), "Zero address not allowed");
        
        signers.push(initialAdmin);
        _signerInfo[initialAdmin] = SignerInfo({
            isValid: true,
            weight: 1
        });
        numValidSigners = 1;
        totalWeight = 1;
        threshold = 1;

        alreadyInit = true;
    }

    // Access control modifiers
    modifier onlySigner() {
        if (!_signerInfo[msg.sender].isValid) revert NotValidSigner();
        _;
    }

    modifier onlyCurrentAdmin() {
        if (msg.sender != IAssetManager(assetManager).owner()) {
            revert NotCurrentAdmin();
        }
        _;
    }

    // Implementation of interface function to get signer info
    function signerInfo(address signer) external view override returns (SignerInfo memory) {
        return _signerInfo[signer];
    }

    // Propose new multi-sig configuration
    function proposeSetupMultiSig(
        address[] memory _signers,
        uint256[] memory _weights,
        uint256 _threshold
    ) external onlyInit onlySigner {
        if (_signers.length != _weights.length) revert InvalidInput();
        
        // Calculate total weight and validate weights
        uint256 _totalWeight = 0;
        for (uint256 i = 0; i < _weights.length; i++) {
            if (_weights[i] == 0) revert InvalidWeight();
            _totalWeight += _weights[i];
        }

        // Validate threshold against total weight
        if (_threshold == 0 || _threshold > _totalWeight) {
            revert InvalidThreshold();
        }

        // Validate signer addresses
        for (uint256 i = 0; i < _signers.length; i++) {
            if (_signers[i] == address(0)) revert ZeroAddressDetected();
            for (uint256 j = i + 1; j < _signers.length; j++) {
                if (_signers[i] == _signers[j]) revert DuplicateSigner();
            }
        }

        uint256 _proposalId = ++proposalId;
        Proposal storage proposal = proposals[_proposalId];
        
        // Calculate and store the proposal hash
        bytes32 proposalHash = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR,
                _proposalId,
                ProposalType.SetupMultiSig,
                _signers,
                _weights,
                _threshold
            )
        );
        proposalHashes[_proposalId] = proposalHash;
        
        proposal.id = _proposalId;
        proposal.proposalType = ProposalType.SetupMultiSig;
        proposal.proposalTime = block.timestamp;
        proposal.totalApprovalWeight = _signerInfo[msg.sender].weight;
        proposal.approvers.push(msg.sender);
        proposal.proposedSigners = _signers;
        proposal.proposedWeights = _weights;
        proposal.proposedThreshold = _threshold;
        
        hasSignedProposal[msg.sender][_proposalId] = true;

        emit ProposalCreated(_proposalId, ProposalType.SetupMultiSig);
    }

    // Asset management proposal functions
    function proposeSetAsset(uint256 assetId, address assetContract) 
        external 
        override 
        onlyInit 
        onlySigner 
    {
        if (assetContract == address(0)) revert ZeroAddressDetected();
        _createProposal(ProposalType.SetAsset, assetId, assetContract);
    }

    function proposeRemoveAsset(uint256 assetId) 
        external 
        override 
        onlyInit 
        onlySigner 
    {
        _createProposal(ProposalType.RemoveAsset, assetId, address(0));
    }

    // Internal function to create new proposals
    function _createProposal(
        ProposalType _type,
        uint256 _assetId,
        address _assetContract
    ) internal {
        uint256 _proposalId = ++proposalId;
        Proposal storage proposal = proposals[_proposalId];
        
        // Calculate and store the proposal hash for asset operations
        bytes32 proposalHash = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR,
                _proposalId,
                _type,
                _assetId,
                _assetContract
            )
        );
        proposalHashes[_proposalId] = proposalHash;
        
        proposal.id = _proposalId;
        proposal.proposalType = _type;
        proposal.assetId = _assetId;
        proposal.assetContract = _assetContract;
        proposal.proposalTime = block.timestamp;
        proposal.totalApprovalWeight = _signerInfo[msg.sender].weight;
        proposal.approvers.push(msg.sender);
        
        hasSignedProposal[msg.sender][_proposalId] = true;

        emit ProposalCreated(_proposalId, _type);
    }

    // Approve and execute proposals
    function approveProposal(uint256 _proposalId) 
        external 
        override 
        onlyInit 
        onlySigner 
    {
        Proposal storage proposal = proposals[_proposalId];
        
        if (proposal.proposalTime == 0) revert ProposalNotFound();
        if (proposal.isCompleted) revert ProposalCompleted();
        if (hasSignedProposal[msg.sender][_proposalId]) revert AlreadyApproved();

        // Verify proposal hash
        bytes32 expectedHash;
        if (proposal.proposalType == ProposalType.SetupMultiSig) {
            expectedHash = keccak256(
                abi.encode(
                    DOMAIN_SEPARATOR,
                    _proposalId,
                    proposal.proposalType,
                    proposal.proposedSigners,
                    proposal.proposedWeights,
                    proposal.proposedThreshold
                )
            );
        } else {
            expectedHash = keccak256(
                abi.encode(
                    DOMAIN_SEPARATOR,
                    _proposalId,
                    proposal.proposalType,
                    proposal.assetId,
                    proposal.assetContract
                )
            );
        }
        if (proposalHashes[_proposalId] != expectedHash) revert InvalidProposalHash();

        uint256 signerWeight = _signerInfo[msg.sender].weight;
        proposal.totalApprovalWeight += signerWeight;
        proposal.approvers.push(msg.sender);
        hasSignedProposal[msg.sender][_proposalId] = true;

        emit ProposalApproved(_proposalId, msg.sender);

        if (proposal.totalApprovalWeight >= threshold) {
            proposal.isCompleted = true;
            _executeProposal(proposal);
            emit ProposalExecuted(_proposalId);
        }
    }

    // Internal function to execute approved proposals
    function _executeProposal(Proposal storage proposal) internal {
        if (proposal.proposalType == ProposalType.SetupMultiSig) {
            // Clear existing signers
            for (uint256 i = 0; i < numValidSigners; i++) {
                _signerInfo[signers[i]] = SignerInfo({
                    isValid: false,
                    weight: 0
                });
            }
            delete signers;

            // Set new signers with weights
            totalWeight = 0;
            for (uint256 i = 0; i < proposal.proposedSigners.length; i++) {
                address signer = proposal.proposedSigners[i];
                uint256 weight = proposal.proposedWeights[i];
                
                _signerInfo[signer] = SignerInfo({
                    isValid: true,
                    weight: weight
                });
                signers.push(signer);
                totalWeight += weight;
            }
            
            numValidSigners = proposal.proposedSigners.length;
            threshold = proposal.proposedThreshold;

            emit MultiSigSetup(proposal.proposedSigners, proposal.proposedWeights, proposal.proposedThreshold);
        } else {
            IAssetManager asset = IAssetManager(assetManager);
            
            if (proposal.proposalType == ProposalType.SetAsset) {
                asset.setAsset(proposal.assetId, proposal.assetContract);
            } else if (proposal.proposalType == ProposalType.RemoveAsset) {
                asset.removeAsset(proposal.assetId);
            }
        }
    }

    // View functions
    function getProposal(uint256 _proposalId) external view override returns (
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
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposalType,
            proposal.assetId,
            proposal.assetContract,
            proposal.proposalTime,
            proposal.totalApprovalWeight,
            proposal.isCompleted,
            proposal.approvers,
            proposal.proposedSigners,
            proposal.proposedWeights,
            proposal.proposedThreshold
        );
    }

    function getSigners() external view override returns (address[] memory) {
        return signers;
    }
}