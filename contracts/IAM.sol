pragma solidity ^0.5.17;

import "./CampaignFactory.sol";

/**
 * @title The identity access manager for Themis
 * @author IS4302 Group 11
 * @notice Stores approved beneficiaries who can use Themis to run donation campaigns
 * @dev This contract will be referenced when CampaignFactory contract needs to verify a beneficiary
 */
contract IAM {
    address owner;
    // The NONE status maps to 0; for unmapped addresses
    enum status { NONE, VERIFIED, LOCK, DISTRUST }
    mapping(address => status) orgStatus;
    mapping(address => uint256) dateOfDistrust;
    address[] orgList;

    /**
     * @notice Emitted when a new beneficiary is added as a verified beneficiary
     * @param org The address of an Ethereum account representing the beneficiary
     */
    event addVerifiedOrg(address org);

    /**
     * @notice Emitted when a beneficiary has been given the status of 'Verified'
     * @param org The address of an Ethereum account representing the beneficiary
     */
    event orgVerified(address org);

    /**
     * @notice Emitted when a beneficiary has been given the status of 'Locked'
     * @param org The address of an Ethereum account representing the beneficiary
     */
    event orgLocked(address org);

    /**
     * @notice Emitted when a beneficiary has been given the status of 'Distrust' 
     * @param org The address of an Ethereum account representing the beneficiary
     */
    event orgDistrust(address org);

    constructor() public {
        owner = msg.sender;
    }

    // --- MODIFIERS ---
    modifier ownerOnly() {
        require(owner == msg.sender, "Caller is not owner");
        _;
    }

    modifier registeredOnly(address organisation) {
        require(orgStatus[organisation] != status.NONE, "Organisation address does not exist");
        _;
    }

    // --- FUNCTIONS ---
    /**
     * @notice Sets a beneficiary to have the 'Verified' status
     * @dev Can only be called by the owner of IAM contract and beneficiary must not have 'NONE' status in orgStatus list
     * @param organisation The address of an Ethereum account representing the beneficiary to set as 'Verified'
     */
    function setVerified(address organisation) public ownerOnly registeredOnly(organisation) {
        orgStatus[organisation] = status.VERIFIED;
        if (dateOfDistrust[organisation] != 0) {
            delete dateOfDistrust[organisation];
        }
        emit orgVerified(organisation);
    }

    /**
     * @notice Sets a beneficiary to have the 'Locked' status
     * @dev Can only be called by the owner of IAM contract and beneficiary must not have 'NONE' status in orgStatus list
     * @param organisation The address of an Ethereum account representing the beneficiary to set as 'Locked'
     */
    function setLocked(address organisation) public ownerOnly registeredOnly(organisation) {
        orgStatus[organisation] = status.LOCK;
        if (dateOfDistrust[organisation] != 0) {
            delete dateOfDistrust[organisation];
        }
        emit orgLocked(organisation);
    }

    /**
     * @notice Sets a beneficiary to have the 'Distrust' status
     * @dev Can only be called by the owner of IAM contract and beneficiary must not have 'NONE' status in orgStatus list
     * @param organisation The address of an Ethereum account representing the beneficiary to set as 'Distrust'
     */
    function setDistrust(address organisation) public ownerOnly registeredOnly(organisation) {
        orgStatus[organisation] = status.DISTRUST;
        dateOfDistrust[organisation] = block.timestamp;
        emit orgDistrust(organisation);
    }

    /**
     * @notice Adds a beneficiary to the list of verified organisations in this IAM contract
     * @dev Can only be called by the owner of IAM contract. Verification of beneficiary is done off the chain
     * @param organisation The address of an Ethereum account representing the newly verified beneficiary to add
     */
    function add(address organisation) public ownerOnly {
        require(orgStatus[organisation] == status.NONE, "Organisation address already exists");
        orgStatus[organisation] = status.VERIFIED;
        orgList.push(organisation);
        emit addVerifiedOrg(organisation);
    }

    /**
     * @notice Checks if a given beneficiary has a 'Verified' status
     * @param organisation The address representing the beneficiary to check
     * @return true if beneficiary has a 'Verified' status, false otherwise
     */
    function isVerified(address organisation) public view returns (bool) {
        return (orgStatus[organisation] == status.VERIFIED);
    }

    function isLocked(address organisation) public view returns (bool) {
        return (orgStatus[organisation] == status.LOCK);
    }

    function isDistrust(address organisation) public view returns (bool) {
        return (orgStatus[organisation] == status.DISTRUST);
    }

    function getStatus(address organisation) public view returns (status) {
        return orgStatus[organisation];
    }

    function getOrgList() public view returns (address[] memory) {
        return orgList;
    }

    function getRefundPeriod(address organisation) public view returns (uint256) {
        require(orgStatus[organisation] == status.DISTRUST, "Organisation is not distrusted");
        require(dateOfDistrust[organisation] != 0, "Organisation's refund period is not found");
        return dateOfDistrust[organisation];
    }
}
