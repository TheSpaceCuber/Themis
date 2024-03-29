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
    enum Status { NONE, VERIFIED, LOCK, DISTRUST }
    mapping(address => Status) orgStatus;
    mapping(address => uint256) dateOfDistrust; // Date is stored in Unix time format
    address[] orgList;

    /**
     * @notice Emitted when a new beneficiary is added as a verified beneficiary
     * @param org The address of an Ethereum account representing the beneficiary
     */
    event AddVerifiedOrg(address org);

    /**
     * @notice Emitted when a beneficiary has been given the status of 'Verified'
     * @param org The address of an Ethereum account representing the beneficiary
     */
    event OrgVerified(address org);

    /**
     * @notice Emitted when a beneficiary has been given the status of 'Locked'
     * @param org The address of an Ethereum account representing the beneficiary
     */
    event OrgLocked(address org);

    /**
     * @notice Emitted when a beneficiary has been given the status of 'Distrust' 
     * @param org The address of an Ethereum account representing the beneficiary
     */
    event OrgDistrust(address org);


    // --- MODIFIERS ---
    modifier ownerOnly() {
        require(owner == msg.sender, "Caller is not owner");
        _;
    }

    modifier registeredOnly(address organisation) {
        require(orgStatus[organisation] != Status.NONE, "Organisation address does not exist");
        _;
    }


    // --- FUNCTIONS ---
    /**
     * @notice Creates a new instance of this IAM contract
     */
    constructor() public {
        owner = msg.sender;
    }

    /**
     * @notice Adds a beneficiary to the list of verified organisations in this IAM contract
     * @dev Can only be called by the owner of IAM contract. Verification of beneficiary is done off the chain
     * @param organisation The address of an Ethereum account representing the newly verified beneficiary to add
     */
    function add(address organisation) public ownerOnly {
        require(orgStatus[organisation] == Status.NONE, "Organisation address already exists");
        orgStatus[organisation] = Status.VERIFIED;
        orgList.push(organisation);
        emit AddVerifiedOrg(organisation);
    }

    /**
     * @notice Sets a beneficiary to have the 'Verified' status
     * @dev Can only be called by the owner of IAM contract and beneficiary must not have 'NONE' status in orgStatus list
     * @param organisation The address of an Ethereum account representing the beneficiary to set as 'Verified'
     */
    function setVerified(address organisation) public ownerOnly registeredOnly(organisation) {
        orgStatus[organisation] = Status.VERIFIED;
        if (dateOfDistrust[organisation] != 0) {
            delete dateOfDistrust[organisation];
        }
        emit OrgVerified(organisation);
    }

    /**
     * @notice Sets a beneficiary to have the 'Locked' status
     * @dev Can only be called by the owner of IAM contract and beneficiary must not have 'NONE' status in orgStatus list
     * @param organisation The address of an Ethereum account representing the beneficiary to set as 'Locked'
     */
    function setLocked(address organisation) public ownerOnly registeredOnly(organisation) {
        orgStatus[organisation] = Status.LOCK;
        if (dateOfDistrust[organisation] != 0) {
            delete dateOfDistrust[organisation];
        }
        emit OrgLocked(organisation);
    }

    /**
     * @notice Sets a beneficiary to have the 'Distrust' status
     * @dev Can only be called by the owner of IAM contract and beneficiary must not have 'NONE' status in orgStatus list
     * @param organisation The address of an Ethereum account representing the beneficiary to set as 'Distrust'
     */
    function setDistrust(address organisation) public ownerOnly registeredOnly(organisation) {
        orgStatus[organisation] = Status.DISTRUST;
        dateOfDistrust[organisation] = block.timestamp;
        emit OrgDistrust(organisation);
    }

    // VIEWS

    function isVerified(address organisation) public view returns (bool) {
        return (orgStatus[organisation] == Status.VERIFIED);
    }

    function isLocked(address organisation) public view returns (bool) {
        return (orgStatus[organisation] == Status.LOCK);
    }

    function isDistrust(address organisation) public view returns (bool) {
        return (orgStatus[organisation] == Status.DISTRUST);
    }

    function getStatus(address organisation) public view returns (Status) {
        return orgStatus[organisation];
    }

    function getOrgList() public view returns (address[] memory) {
        return orgList;
    }

    function getRefundPeriod(address organisation) public view returns (uint256) {
        require(orgStatus[organisation] == Status.DISTRUST, "Organisation is not distrusted");
        require(dateOfDistrust[organisation] != 0, "Organisation's refund period is not found");
        return dateOfDistrust[organisation];
    }
}
