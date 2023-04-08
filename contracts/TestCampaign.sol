pragma solidity ^0.5.17;

import "./IAM.sol";
import "./TestCampaignFactory.sol";

contract TestCampaign {
    address payable campaignFactory;
    address owner;
    uint256 endDatetime;
    IAM IAMContract;
    uint256 totalDonated = 0;
    uint256 commissionBP = 1000; // 10% == (1000 / 10,000) basis points
    uint256 basispoints = 10000;

    event campaignInfo(address owner, string status, uint256 endDatetime, uint256 totalDonated);
    event donationMade(address donor, uint256 donatedAmt);
    event hasWithdrawn(address from, uint256 totalDonationAmt);
    event hasRefunded(address donor, uint256 refundedAmt);

    constructor(uint256 secs, address orgAddress, IAM IAMaddress 
        ) public {
        endDatetime = block.timestamp + secs;
        owner = orgAddress;
        campaignFactory = msg.sender;
        IAMContract = IAMaddress;
    }

    // --- MODIFIERS ---
    modifier ownerOnly() {
        require(owner == msg.sender, "Caller is not owner");
        _;
    }

    modifier verifiedOnly() {
        require(isVerifiedOwner() == true, "Address is not verified");
        _;
    }

    modifier distrustOnly() {
        require(isDistrustedOwner() == true, "Organisation status is not distrust");
        _;
    }

    modifier campaignFactoryOnly() {
        require(campaignFactory == msg.sender, "Not called from campaignFactory contract");
        _;
    }

    modifier ongoingCampaignOnly(bool test_isPastLockout) {
        require(test_isPastLockout == false, "Campaign has ended");
        _;
    }

    modifier pastLockoutOnly(bool test_isPastLockout) {
        require(test_isPastLockout == true, "Campaign is ongoing");
        _;
    }

    // --- GETTERS / SETTERS ---
    
    function isVerifiedOwner() public view returns (bool) {
        return IAMContract.isVerified(owner);
    }

    function isDistrustedOwner() public view returns (bool) {
        return IAMContract.isDistrust(owner);
    }

    function isPastLockout(uint256 test_currentDatetime) public view returns (bool) {
        return test_currentDatetime >= endDatetime;
    }

    function getCharityOrganisation() public view returns (address) {
        return owner;
    }

    function getCampaignInfo() public {
        uint256 statusInt = uint256(IAMContract.getStatus(owner));
        string memory status;
        if (statusInt == 1) {
            status = "Verified";
        } else if (statusInt == 2) {
            status = "Locked";
        } else {
            status = "Distrust";
        }
        emit campaignInfo(owner, status, endDatetime, totalDonated);
    }

    function getEndDatetime() public view returns (uint256) {
        return endDatetime;
    }

    function getTotalDonated() public view returns (uint256) {
        return totalDonated;
    }
    
    // --- FUNCTIONS ---
    function donate(bool test_isPastLockout) public payable verifiedOnly ongoingCampaignOnly(test_isPastLockout) {
        require(msg.value > 0, "Invalid donation amount");
        totalDonated += msg.value;
        emit donationMade(msg.sender, msg.value);
    }

    function withdraw(bool test_isPastLockout) public ownerOnly verifiedOnly pastLockoutOnly(test_isPastLockout) {
        uint256 commission = (totalDonated * commissionBP) / basispoints;
        
        address payable campgnFactory = address(uint160(campaignFactory));
        address payable beneficiary = address(uint160(owner));
        uint256 netDonationAmt =  totalDonated - commission;

        campgnFactory.transfer(commission);
        beneficiary.transfer(netDonationAmt);
        emit hasWithdrawn(beneficiary, netDonationAmt);

        TestCampaignFactory(campaignFactory).closeCampaign(owner, this, test_isPastLockout);
    }

    // pseudo-code for follow up    
    function refund(address campaignAddr) public campaignFactoryOnly distrustOnly {

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
