pragma solidity ^0.5.17;

import "./CampaignFactory.sol";

contract IAM {
    address owner;

    // the NONE status maps to 0; for unmapped addresses
    enum status { NONE, VERIFIED, LOCK, DISTRUST }
    mapping(address => status) orgStatus;
    mapping(address => uint256) dateOfDistrust;
    address[] orgList;

    event addVerifiedOrg(address org);
    event orgVerified(address org);
    event orgLocked(address org);
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

    // --- GETTERS / SETTERS ---
    // may be used later
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

    function setVerified(address organisation) public ownerOnly registeredOnly(organisation) {
        orgStatus[organisation] = status.VERIFIED;
        if (dateOfDistrust[organisation] != 0) {
            delete dateOfDistrust[organisation];
        }
        emit orgVerified(organisation);
    }

    function setLocked(address organisation) public ownerOnly registeredOnly(organisation) {
        orgStatus[organisation] = status.LOCK;
        if (dateOfDistrust[organisation] != 0) {
            delete dateOfDistrust[organisation];
        }
        emit orgLocked(organisation);
    }

    function setDistrust(address organisation) public ownerOnly registeredOnly(organisation) {
        orgStatus[organisation] = status.DISTRUST;
        dateOfDistrust[organisation] = block.timestamp;
        emit orgDistrust(organisation);
    }

    // --- FUNCTIONS ---
    // adds a verified organisation
    function add(address organisation) public ownerOnly {
        require(orgStatus[organisation] == status.NONE, "Organisation address already exists");
        orgStatus[organisation] = status.VERIFIED;
        orgList.push(organisation);
        emit addVerifiedOrg(organisation);
    }
}
