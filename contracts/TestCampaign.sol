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

    /**
     * @notice Emitted when a new beneficiary is added as a verified beneficiary
     * @param owner The address of the beneficiary managing this donation campaign
     * @param status The status of the campaign, that is, 'Verified', 'Locked', or 'Distrust'
     * @param endDatetime The Unix timestamp when the contract is scheduled to end
     * @param totalDonated The total amount of money donated to the point of this event being emitted
     */
    event campaignInfoRetrieved(address owner, string status, uint256 endDatetime, uint256 totalDonated);
    
    /**
     * @notice Emitted when a donation is made to the campaign
     * @param donor The address representing the donor who has donated
     * @param donatedAmt The amount of money donated by the donor
     */
    event donationMade(address donor, uint256 donatedAmt);
    
    /**
     * @notice Emitted when the beneficiary has taken out the donation pool from this campaign
     * @dev Should only be emitted when this campaign has ended
     * @param from The address that the donation pool has been transferred to (should be owner variable)
     * @param totalDonationAmt The value of the donation pool at the time of withdrawal
     */
    event hasWithdrawn(address from, uint256 totalDonationAmt);
    
    /**
     * @notice Emitted when a donor has taken his/her donation back in the event that this campaign is distrusted
     * @param donor The address of the donor who has gotten a refund
     * @param refundedAmt The value of the refund
     */
    event hasRefunded(address donor, uint256 refundedAmt);

    /**
     * @notice Emitted when the remaining unclaimed donations has been transferred to CampaignFactory contract
     * in the event that this campaign is distrusted and there are still unclaimed donations in the contract
     * @param from This Campaign contract address
     * @param returnedAmt The value of the unclaimed donations transferred
     */
    event hasReturnedBalance(address from, uint256 returnedAmt);
    

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
     * @dev Contains a test-specific parameter
     */
    modifier ongoingCampaignOnly(bool test_isPastLockout) {
        require(test_isPastLockout == false, "Campaign has ended");
        _;
    }

    /**
     * @dev Contains a test-specific parameter
     */
    modifier pastLockoutOnly(bool test_isPastLockout) {
        require(test_isPastLockout == true, "Campaign is ongoing");
        _;
    }


    // --- FUNCTIONS ---
    /**
     * @notice Instantiates a new Campaign contract for donors to donate to
     * @param secs The duration in seconds that this campaign will run for
     * @param orgAddress The address of the beneficiary that is running this campaign
     * @param IAMaddress The address of the IAM contract for beneficiary verification purposes
     */
    constructor(uint256 secs, address orgAddress, IAM IAMaddress) public {
        endDatetime = block.timestamp + secs;
        owner = address(uint160(orgAddress));
        campaignFactory = msg.sender;
        IAMContract = IAMaddress;
    }

    /**
     * @notice Retrieve information about this campaign, including its status, ending timestamp,
     * the beneficiary in-charge, and the total amount of money donated so far
     * @dev The status names in this function follows that of the status enumeration variable in
     * the IAM contract
     */
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
        emit campaignInfoRetrieved(owner, status, endDatetime, totalDonated);
    }

    /**
     * @notice Allows donors to donate to this Campaign contract.
     * @dev This function only works if the campaign's status is 'Verified' and ongoing
     */
    function donate(bool test_isPastLockout) public payable verifiedOnly ongoingCampaignOnly(test_isPastLockout) {
        require(msg.value > 0, "Invalid donation amount");
        totalDonated += msg.value;
        emit donationMade(msg.sender, msg.value);
    }

    /**
     * @notice Allows the managing beneficiary to take the donations from this Campaign contract after
     * the campaign has ended and is not under suspicion for fraud
     * @dev Commission will also be transferred to CampaignFactory contract from this function
     */
    function withdraw(bool test_isPastLockout) public ownerOnly verifiedOnly pastLockoutOnly(test_isPastLockout) {
        uint256 commission = (totalDonated * commissionBP) / basispoints;
        uint256 netDonationAmt =  totalDonated - commission;

        campaignFactory.transfer(commission);
        owner.transfer(netDonationAmt);
        emit hasWithdrawn(owner, netDonationAmt);

        TestCampaignFactory(campaignFactory).closeCampaign(owner, this, test_isPastLockout);
    }

    /**
     * @notice Allows donors to reclaim their donations in the event that this campaign or the managing
     * beneficiary is deemed to be untrustworthy
     * @dev Currently only contains pseduocode
     * @param campaignAddr The address of this Campaign contract
     */
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

    /**
     * @notice Allows the CampaignFactory contract to transfer any unclaimed donations to itself in the
     * event that campaign or managing beneficiary is deemed to be untrustworthy
     * @dev The time to call this function is left to the discretion of the CampaignFactory contract
     */
    function returnRemainingBalance() public campaignFactoryOnly distrustOnly {
        uint256 remainingBalance =  address(this).balance;
        campaignFactory.transfer(remainingBalance);
        emit hasReturnedBalance(address(this), remainingBalance);
    }

    /**
     * @notice Checks if the managing beneficiary has the 'Verified' status
     * @dev Data is based on the IAM contract
     * @return true if the beneficiary has the 'Verified' status, false otherwise
     */
    function isVerifiedOwner() public view returns (bool) {
        return IAMContract.isVerified(owner);
    }

    /**
     * @notice Checks if the managing beneficiary has the 'Distrust' status
     * @dev Data is based on the IAM contract
     * @return true if the beneficiary has the 'Distrust' status, false otherwise
     */
    function isDistrustedOwner() public view returns (bool) {
        return IAMContract.isDistrust(owner);
    }

    /**
     * @notice Checks if this campaign has already ended based on the stated date and time
     * given when this Campaign contract was instantiated
     * @dev Parameter is modified from original Campaign contract to allow for a specific
     * date and time to be tested
     * @return true if the campaign has ended, false otherwise
     */
    function isPastLockout(uint256 test_currentDatetime) public view returns (bool) {
        return test_currentDatetime >= endDatetime;
    }

    /**
     * @notice Gets the managing beneficiary running this campaign
     * @return An address representing the beneficiary
     */
    function getCharityOrganisation() public view returns (address) {
        return owner;
    }

    /**
     * @notice Gets the date and time of when this campaign is scheduled to end
     * @dev Ending date and time was declared during this contract's instantiation
     * @return A Unix timestamp representing the campaign's ending date and time
     */
    function getEndDatetime() public view returns (uint256) {
        return endDatetime;
    }

    /**
     * @notice Gets the total amount donated at the time of this function call
     * @return The value of the donation pool
     */
    function getTotalDonated() public view returns (uint256) {
        return totalDonated;
    }
}
