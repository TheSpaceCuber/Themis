pragma solidity ^0.5.17;

import "./Campaign.sol";
import "./IAM.sol";

/**
 * @title The brains of Themis
 * @author IS4302 Group 11
 * @notice Creates, closes, and manages campaigns
 */
contract CampaignFactory {
    address owner;
    IAM IAMContract;
    uint8 MAX_CHARITIES = 5;
    uint16 HoursInYear = 8760;
    uint16 SecsInHour = 3600;
    mapping(address => address[]) orgCampaigns;

    /**
     * @notice Emitted when a new Campaign contract is instantiated
     * @param organisation The beneficiary that is running the campaign
     * @param campaign The address of the newly instantiated Campaign contract
     * @param durationHrs The duration that the campaign will run for
     */
    event mountCampaign(address organisation, address campaign, uint256 durationHrs);

    /**
     * @notice Emitted when a campaign has ended and is closed
     * @param organisation The beneficiary that was in-charge of the campaign
     * @param campaign The address of the closing Campaign contract
     */
    event campaignEnded(address organisation, address campaign);

    /**
     * @notice Emitted when the commission money in this CampaignFactory contract is withdrawn
     * @param amt The value of the commission withdrawn
     */
    event commissionWithdrawn(uint256 amt);

    /**
     * @notice Emitted when a campaign contract has been deleted. Used when a campaign or its 
     * managing beneficiary is deemed to be untrustworthy
     * @param organisation The beneficiary that was running the campaign
     * @param campaign The address of the deleted Campaign contract
     */
    event campaignDeleted(address organisation, address campaign);

    /**
     * @notice Emitted when a beneficiary has been deleted from this contract's orgCampaigns mapping
     * @param organisation The beneficiary that has been deleted
     */
    event orgDeleted(address organisation);

    /**
     * @notice Emitted when all donations made to an untrustworthy campaign has been refunded, including
     * transferring any unclaimed donations to this CampaignFactory contract
     * @param organisation The beneficiary that was in-charge of the distrusted campaign
     */
    event refundComplete(address organisation);

    // --- MODIFIERS ---
    modifier ownerOnly() {
        require(owner == msg.sender, "Caller is not owner");
        _;
    }

    modifier verifiedOnly() {
        require(isVerified(msg.sender) == true, "Address is not verified");
        _;
    }

    // --- GETTERS / SETTERS ---
    constructor(IAM IAMaddress) public {
        owner = msg.sender;
        IAMContract = IAMaddress;
    }

    // For receiving payment
    function() payable external {}

    function isVerified(address organisation) public view returns (bool) {
        return IAMContract.isVerified(organisation);
    }

    function isLocked(address organisation) public view returns (bool) {
        return IAMContract.isLocked(organisation);
    }

    function isDistrust(address organisation) public view returns (bool) {
        return IAMContract.isDistrust(organisation);
    }

    function hoursToSeconds(uint16 hrs) private view returns (uint256) {
        return uint256(SecsInHour  * hrs);
    }

    function secondsInSixMonths() private view returns (uint256) {
        return hoursToSeconds(HoursInYear) / 2;
    }

    function getCampaignsOfOrg(address organisation) public view returns (address[] memory) {
        return orgCampaigns[organisation];
    }

    // --- FUNCTIONS ---
    
    
    
    // overloaded
    function addCampaign() public verifiedOnly returns (Campaign) {
        require(orgCampaigns[msg.sender].length < MAX_CHARITIES, "Maximum active charities reached");

        uint256 durationSecs = hoursToSeconds(HoursInYear);
        Campaign c = new Campaign(durationSecs, msg.sender, IAMContract);
        orgCampaigns[msg.sender].push(address(c));

        emit mountCampaign(msg.sender, address(c), HoursInYear);
        return c;
    }

    // overloaded
    // If organisation specifies duration of campaign in hours
    function addCampaign(uint16 durationHrs) public verifiedOnly returns (Campaign) {
        require(durationHrs >= 24, "Minimum duration (hrs) is 24 hour");
        require(durationHrs <= HoursInYear, "Maximum duration (in hrs) is 1 year");
        require(orgCampaigns[msg.sender].length < MAX_CHARITIES, "Maximum active charities reached");

        uint256 durationSecs = hoursToSeconds(durationHrs);
        Campaign c = new Campaign(durationSecs, msg.sender, IAMContract);
        orgCampaigns[msg.sender].push(address(c));

        emit mountCampaign(msg.sender, address(c), durationHrs);
        return c;
    }

    // called from Campaign.sol after beneficiary withdraw()
    function closeCampaign(address organisation, Campaign campaign) public {
        require(isVerified(organisation) == true, "Address is not verified");
        require(campaign.isPastLockout() == true, "Campaign is ongoing");
        require(tx.origin == organisation, "Caller is not owner");
        require(msg.sender == address(campaign), "Not called from Campaign contract");

        // delete campaign from active list
        uint256 len = orgCampaigns[organisation].length - 1;
        for (uint i = 0; i < len; i++) {
            if (orgCampaigns[organisation][i+1] != address(campaign)) {
                orgCampaigns[organisation][i] = orgCampaigns[organisation][i+1];
            }
        }
        orgCampaigns[organisation].pop();
        emit campaignEnded(organisation, address(campaign));
    }

    // withdraw commission
    function withdrawCommissions() public ownerOnly {
        require(address(this).balance > 0, "No remaining balance");
        address payable ownerAddr = address(uint160(owner));
        uint256 amount = address(this).balance;

        ownerAddr.transfer(amount);
        emit commissionWithdrawn(amount);
    }

    function deleteDistrustedOrg(address organisation) public ownerOnly {
        require(isDistrust(organisation) == true, "Organisation status is not distrust");
        require(block.timestamp >= IAMContract.getRefundPeriod(organisation) + secondsInSixMonths(), "Refund period is ongoing");
        uint256 len = orgCampaigns[organisation].length - 1;
        for (int i = int(len); i >= 0; i--) {
            Campaign c = Campaign(orgCampaigns[organisation][uint256(i)]);
            c.returnRemainingBalance();
            deleteCampaignFromMapping(organisation, c);
        }
        deleteOrgFromMapping(organisation);
        emit refundComplete(organisation);
    }

    function deleteCampaignFromMapping(address organisation, Campaign campaign) private {
        orgCampaigns[organisation].pop();
        emit campaignDeleted(organisation, address(campaign));
    }

    function deleteOrgFromMapping(address organisation) private {
        delete orgCampaigns[organisation];
        emit orgDeleted(organisation);
    }
}
