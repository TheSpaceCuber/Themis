pragma solidity ^0.5.17;

import "./IAM.sol";
import "./CampaignFactory.sol";

contract Campaign {
    address manager;        // the factory
    address owner;
    uint256 lockoutEndDatetime;
    IAM IAMContract;
    uint256 totalDonated = 0;
    uint256 commissionBP = 1000; // 10% == (1000 / 10,000) basis points
    uint256 basispoints = 10000;

    event donationMade (address donor, uint256 donatedAmt);
    event hasWithdrawn (address from, uint256 totalDonationAmt);
    event hasRefunded (address donor, uint256 refundedAmt);

    constructor(uint256 secs, address orgAddress, IAM IAMaddress 
        ) public {
        lockoutEndDatetime = block.timestamp + secs;
        owner = orgAddress;
        manager = msg.sender;
        IAMContract = IAMaddress;
    }

    // --- MODIFIERS ---
    modifier ownerOnly() {
        require(owner == msg.sender);
        _;
    }

    modifier verifiedOnly() {
        require(isVerifiedOwner() == true);
        _;
    }

    modifier distrustOnly() {
        require(isDistrustedOwner() == true);
        _;
    }

    modifier managerOnly() {
        require(manager == msg.sender);
        _;
    }

    modifier withinLockoutOnly() {
        require(isPastLockout() == false);
        _;
    }

    modifier pastLockoutOnly() {
        require(isPastLockout() == true);
        _;
    }

    // --- GETTERS / SETTERS ---
    
    function isVerifiedOwner() public view returns (bool) {
        return IAMContract.isVerified(owner);
    }

    function isDistrustedOwner() public view returns (bool) {
        return IAMContract.isDistrust(owner);
    }

    function isPastLockout() public view returns (bool) {
        return block.timestamp >= lockoutEndDatetime;
    }

    function getCharityOrganisation() public view returns (address) {
        return owner;
    }

    function getLockoutEndDatetime() public view returns (uint256) {
        return lockoutEndDatetime;
    }

    function getTotalDonated() public view returns (uint256) {
        return totalDonated;
    }
    
    // --- FUNCTIONS ---
    function donate() public payable verifiedOnly withinLockoutOnly {
        require(msg.value > 0);
        totalDonated += msg.value;
        emit donationMade(msg.sender, msg.value);
    }

    function withdraw() public ownerOnly verifiedOnly pastLockoutOnly {
        uint256 commission = (totalDonated * commissionBP) / basispoints;
        
        address payable platform = address(uint160(manager));
        address payable beneficiary = address(uint160(owner));
        uint256 toBeDonated =  totalDonated - commission;

        platform.transfer(commission);
        beneficiary.transfer(toBeDonated);
        emit hasWithdrawn(beneficiary, toBeDonated);
    }

    // pseudo-code for follow up    
    function refund(address campaignAddr) public managerOnly distrustOnly {

        //retrieve past transactions/events here using campaignAddr
        /*
        let contractJSON = require('./CampaignTest.json');
        let contractABI = contractJSON.abi;

        let CampaignTestContract = new web3.eth.Contract(contractABI, campaignAddr);

        CampaignTestContract.getPastEvents("donationMade", options, (error, events) => {
        if (error) {
            console.log(error);
        } else {
            //for each event, parse out sender and value
            //sender.transfer(value)
            //emit hasRefunded(sender, value);
        }
        */
    }
}
