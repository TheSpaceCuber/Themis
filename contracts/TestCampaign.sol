pragma solidity ^0.5.17;

import "./IAM.sol";
import "./TestCampaignFactory.sol";

/**
 * @title A donation campaign for donors to donate money to
 * @author IS4302 Group 11
 * @notice Donors can donate to this campaign during the campaign period
 * @dev Instantiation of this contract should only be done through CampaignFactory contract.
 * This test contract has some minor variations from Campaign.sol to allow for specific
 * time values to be tested on.
 */
contract TestCampaign {
    address payable campaignFactory;
    address payable owner;              // The beneficiary running this donation campaign
    IAM IAMContract;
    uint256 endDatetime;
    uint256 totalDonated = 0;
    uint256 commissionBP = 1000;        // 10% == (1000 / 10,000) basis points
    uint256 basispoints = 10000;

    event CampaignInfoRetrieved(address owner, string status, uint256 endDatetime, uint256 totalDonated);
    event DonationMade(address donor, uint256 donatedAmt);
    event HasWithdrawn(address from, uint256 totalDonationAmt);
    event HasRefunded(address donor, uint256 refundedAmt);
    event HasReturnedBalance(address from, uint256 returnedAmt);
    

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

    /**
     * @param test_isPastLockout A test parameter to specify if a campaign has ended
     */
    modifier ongoingCampaignOnly(bool test_isPastLockout) {
        require(test_isPastLockout == false, "Campaign has ended");
        _;
    }

    /**
     * @param test_isPastLockout A test parameter to specify if a campaign has ended
     */
    modifier pastLockoutOnly(bool test_isPastLockout) {
        require(test_isPastLockout == true, "Campaign is ongoing");
        _;
    }


    // --- FUNCTIONS ---
    constructor(uint256 secs, address orgAddress, IAM IAMaddress) public {
        endDatetime = block.timestamp + secs;
        owner = address(uint160(orgAddress));
        campaignFactory = msg.sender;
        IAMContract = IAMaddress;
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
        emit CampaignInfoRetrieved(owner, status, endDatetime, totalDonated);
    }

    function donate(bool test_isPastLockout) public payable verifiedOnly ongoingCampaignOnly(test_isPastLockout) {
        require(msg.value > 0, "Invalid donation amount");
        totalDonated += msg.value;
        emit DonationMade(msg.sender, msg.value);
    }

    function withdraw(bool test_isPastLockout) public ownerOnly verifiedOnly pastLockoutOnly(test_isPastLockout) {
        uint256 commission = (totalDonated * commissionBP) / basispoints;
        uint256 netDonationAmt =  totalDonated - commission;

        campaignFactory.transfer(commission);
        owner.transfer(netDonationAmt);
        emit HasWithdrawn(owner, netDonationAmt);

        TestCampaignFactory(campaignFactory).closeCampaign(owner, this, test_isPastLockout);
    }

    function refund(address campaignAddr) public campaignFactoryOnly distrustOnly {

        //retrieve past transactions/events here using campaignAddr
        /*
        let contractJSON = require('./CampaignTest.json');
        let contractABI = contractJSON.abi;

        let CampaignTestContract = new web3.eth.Contract(contractABI, campaignAddr);

        CampaignTestContract.getPastEvents("DonationMade", options, (error, events) => {
        if (error) {
            console.log(error);
        } else {
            //for each event, parse out sender and value
            //sender.transfer(value)
            //emit HasRefunded(sender, value);
        }
        */
    }

    function returnRemainingBalance() public campaignFactoryOnly distrustOnly {
        uint256 remainingBalance =  address(this).balance;
        campaignFactory.transfer(remainingBalance);
        emit HasReturnedBalance(address(this), remainingBalance);
    }

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

    function getEndDatetime() public view returns (uint256) {
        return endDatetime;
    }

    function getTotalDonated() public view returns (uint256) {
        return totalDonated;
    }
}
