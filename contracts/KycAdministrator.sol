// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interface/IKycManager.sol";
import "./interface/IKycAdministrator.sol";
import "./System.sol";

contract KycAdministrator is IKycAdministrator, System {
    // Add domain separator for multi-sig proposals
    bytes32 public constant DOMAIN_SEPARATOR = keccak256("KycAdministrator_V1");

    // State variables for multi-sig management
    address[] public signers;
    uint256 public threshold;
    uint256 public numValidSigners;
    uint256 public totalWeight;
    uint256 public proposalId;
    uint256 public proposalExpiration = 7 days;

    // Proposal structure for all administrative actions
    struct Proposal {
        uint256 id;
        ProposalType proposalType;
        address proposedAdmin;     // for TransferAdmin
        uint256 regionId;         // for Region operations
        address regionAdmin;      // for RegionAdmin operations
        uint256 proposalTime;
        uint256 totalApprovalWeight;
        bool isCompleted;
        bool isCancelled;
        address creator;
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
    
    // Constant address for KYC Manager contract
    address public constant kycManager = KYC_MANAGER_ADDR;   

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
        if (msg.sender != IKycManager(kycManager).globalAdmin()) {
            revert NotCurrentAdmin();
        }
        _;
    }

    modifier onlyValidProposal(uint256 _proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        if (proposal.proposalTime == 0) revert ProposalNotFound();
        if (proposal.isCompleted) revert ProposalCompleted();
        if (proposal.isCancelled) revert InvalidProposalState();
        if (block.timestamp > proposal.proposalTime + proposalExpiration) revert ProposalExpired();
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
        proposal.creator = msg.sender;
        proposal.proposedSigners = _signers;
        proposal.proposedWeights = _weights;
        proposal.proposedThreshold = _threshold;
        
        hasSignedProposal[msg.sender][_proposalId] = true;

        emit ProposalCreated(_proposalId, ProposalType.SetupMultiSig);
    }

    // Region management proposal functions
    function proposeAddRegion(uint256 _regionId) 
        external 
        override 
        onlyInit 
        onlySigner 
        onlyCurrentAdmin 
    {
        _createProposal(ProposalType.AddRegion, address(0), _regionId, address(0));
    }

    function proposeRemoveRegion(uint256 _regionId) 
        external 
        override 
        onlyInit 
        onlySigner 
        onlyCurrentAdmin 
    {
        _createProposal(ProposalType.RemoveRegion, address(0), _regionId, address(0));
    }

    function proposeAddRegionAdmin(uint256 _regionId, address _admin) 
        external 
        override 
        onlyInit 
        onlySigner 
        onlyCurrentAdmin 
    {
        if (_admin == address(0)) revert ZeroAddressDetected();
        _createProposal(ProposalType.AddRegionAdmin, address(0), _regionId, _admin);
    }

    function proposeRemoveRegionAdmin(uint256 _regionId, address _admin) 
        external 
        override 
        onlyInit 
        onlySigner 
        onlyCurrentAdmin 
    {
        _createProposal(ProposalType.RemoveRegionAdmin, address(0), _regionId, _admin);
    }

    function proposeToggleState() 
        external 
        override 
        onlyInit 
        onlySigner 
        onlyCurrentAdmin 
    {
        _createProposal(ProposalType.ToggleState, address(0), 0, address(0));
    }

    // Internal function to create new proposals
    function _createProposal(
        ProposalType _type,
        address _proposedAdmin,
        uint256 _regionId,
        address _regionAdmin
    ) internal {
        uint256 _proposalId = ++proposalId;
        Proposal storage proposal = proposals[_proposalId];
        
        // Calculate and store the proposal hash
        bytes32 proposalHash = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR,
                _proposalId,
                _type,
                _proposedAdmin,
                _regionId,
                _regionAdmin
            )
        );
        proposalHashes[_proposalId] = proposalHash;
        
        proposal.id = _proposalId;
        proposal.proposalType = _type;
        proposal.proposedAdmin = _proposedAdmin;
        proposal.regionId = _regionId;
        proposal.regionAdmin = _regionAdmin;
        proposal.proposalTime = block.timestamp;
        proposal.totalApprovalWeight = _signerInfo[msg.sender].weight;
        proposal.approvers.push(msg.sender);
        proposal.creator = msg.sender;
        
        hasSignedProposal[msg.sender][_proposalId] = true;

        emit ProposalCreated(_proposalId, _type);
    }

    // Cancel proposal
    function cancelProposal(uint256 _proposalId) 
        external 
        override 
        onlyInit 
        onlyValidProposal(_proposalId) 
    {
        Proposal storage proposal = proposals[_proposalId];
        if (proposal.creator != msg.sender) revert NotProposalCreator();
        
        proposal.isCancelled = true;
        emit ProposalCancelled(_proposalId);
    }

    // Approve and execute proposals
    function approveProposal(uint256 _proposalId) 
        external 
        override 
        onlyInit 
        onlySigner
        onlyValidProposal(_proposalId)
    {
        Proposal storage proposal = proposals[_proposalId];
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
                    proposal.proposedAdmin,
                    proposal.regionId,
                    proposal.regionAdmin
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
            IKycManager kyc = IKycManager(kycManager);
            
            if (proposal.proposalType == ProposalType.AddRegion) {
                kyc.addRegionId(proposal.regionId);
            } else if (proposal.proposalType == ProposalType.RemoveRegion) {
                kyc.removeRegionId(proposal.regionId);
            } else if (proposal.proposalType == ProposalType.AddRegionAdmin) {
                kyc.addRegionAdmin(proposal.regionId, proposal.regionAdmin);
            } else if (proposal.proposalType == ProposalType.RemoveRegionAdmin) {
                kyc.removeRegionAdmin(proposal.regionId, proposal.regionAdmin);
            } else if (proposal.proposalType == ProposalType.ToggleState) {
                kyc.toggleContractState();
            }
        }
    }

    // View functions
    function getProposal(uint256 _proposalId) external view override returns (
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
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposalType,
            proposal.proposedAdmin,
            proposal.regionId,
            proposal.regionAdmin,
            proposal.proposalTime,
            proposal.totalApprovalWeight,
            proposal.isCompleted,
            proposal.isCancelled,
            proposal.creator,
            proposal.approvers,
            proposal.proposedSigners,
            proposal.proposedWeights,
            proposal.proposedThreshold
        );
    }

    function getSigners() external view override returns (address[] memory) {
        return signers;
    }

    // Add function to update proposal expiration time (only through multi-sig)
    function setProposalExpiration(uint256 _newExpiration) external onlyInit {
        if (msg.sender != address(this)) revert NotAuthorized();
        proposalExpiration = _newExpiration;
    }
}