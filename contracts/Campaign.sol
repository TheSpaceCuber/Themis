pragma solidity ^0.5.17;

import "./IAM.sol";
import "./CampaignFactory.sol";

/**
 * @title A donation campaign for donors to donate money to
 * @author IS4302 Group 11
 * @notice Donors can donate to this campaign during the campaign period
 * @dev Instantiation of this contract should only be done through CampaignFactory contract
 */
contract Campaign {
    address payable campaignFactory;
    address payable owner;              // The beneficiary running this donation campaign
    IAM IAMContract;
    uint256 endDatetime;
    uint256 totalDonated = 0;
    uint256 commissionBP = 1000;        // 10% == (1000 / 10,000) basis points
    uint256 basisPoints = 10000;

    /**
     * @notice Emitted when a new beneficiary is added as a verified beneficiary
     * @param owner The address of the beneficiary managing this donation campaign
     * @param status The status of the campaign, that is, 'Verified', 'Locked', or 'Distrust'
     * @param endDatetime The Unix timestamp when the contract is scheduled to end
     * @param totalDonated The total amount of money donated to the point of this event being emitted
     */
    event CampaignInfoRetrieved(address owner, string status, uint256 endDatetime, uint256 totalDonated);

    /**
     * @notice Emitted when a donation is made to the campaign
     * @param donor The address representing the donor who has donated
     * @param donatedAmt The amount of money donated by the donor
     */
    event DonationMade(address donor, uint256 donatedAmt);

    /**
     * @notice Emitted when the beneficiary has taken out the donation pool from this campaign
     * @dev Should only be emitted when this campaign has ended
     * @param from The address that the donation pool has been transferred to (should be owner variable)
     * @param totalDonationAmt The value of the donation pool at the time of withdrawal
     */
    event HasWithdrawn(address from, uint256 totalDonationAmt);

    /**
     * @notice Emitted when a donor has taken his/her donation back in the event that this campaign is distrusted
     * @param donor The address of the donor who has gotten a refund
     * @param refundedAmt The amount refunded to the donor
     */
    event HasRefunded(address donor, uint256 refundedAmt);

    /**
     * @notice Emitted when the remaining unclaimed donations has been transferred to CampaignFactory contract
     * in the event that this campaign is distrusted and there are still unclaimed donations in the contract
     * @param from This Campaign contract address
     * @param returnedAmt The value of the unclaimed donations transferred
     */
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

    modifier ongoingCampaignOnly() {
        require(isPastLockout() == false, "Campaign has ended");
        _;
    }

    modifier pastLockoutOnly() {
        require(isPastLockout() == true, "Campaign is ongoing");
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
        emit CampaignInfoRetrieved(owner, status, endDatetime, totalDonated);
    }

    /**
     * @notice Allows donors to donate to this Campaign contract.
     * @dev This function only works if the campaign's status is 'Verified' and ongoing
     */
    function donate() public payable verifiedOnly ongoingCampaignOnly {
        require(msg.value > 0, "Invalid donation amount");
        totalDonated += msg.value;
        emit DonationMade(msg.sender, msg.value);
    }

    /**
     * @notice Allows the managing beneficiary to take the donations from this Campaign contract after
     * the campaign has ended and is not under suspicion for fraud
     * @dev Commission will also be transferred to CampaignFactory contract from this function
     */
    function withdraw() public ownerOnly verifiedOnly pastLockoutOnly {
        uint256 commission = (totalDonated * commissionBP) / basisPoints;
        uint256 netDonationAmt =  totalDonated - commission;

        campaignFactory.transfer(commission);
        owner.transfer(netDonationAmt);
        emit HasWithdrawn(owner, netDonationAmt);

        CampaignFactory(campaignFactory).closeCampaign(owner, this);
    }
    
    /**
     * @notice Allows donors to reclaim their donations in the event that this campaign or the managing
     * beneficiary is deemed to be untrustworthy
     * @dev Currently only contains pseduocode
     * @param donor the address of the person who donated
     * @param amt the amount of money to be refunded
     */
    function refund(address payable donor, uint256 amt) public distrustOnly {
        require(amt > 0, "No amount to refund");
        require(msg.sender == donor);
        donor.transfer(amt);
        emit HasRefunded(donor, amt);
    }

    /**
     * @notice Allows the CampaignFactory contract to transfer any unclaimed donations to itself in the
     * event that campaign or managing beneficiary is deemed to be untrustworthy
     * @dev The time to call this function is left to the discretion of the CampaignFactory contract
     */
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

    function isPastLockout() public view returns (bool) {
        return block.timestamp >= endDatetime;
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
