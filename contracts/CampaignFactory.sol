pragma solidity ^0.5.17;

import "./Campaign.sol";
import "./IAM.sol";

/**
 * @title Creation, closure, and management of campaigns
 * @author IS4302 Group 11
 * @notice Handles the creation and management of campaigns
 */
contract CampaignFactory {
    address owner;
    IAM IAMContract;
    uint8 MAX_CHARITIES = 5;
    uint16 HoursInYear = 8760;
    uint16 SecsInHour = 3600;
    mapping(address => address[]) orgCampaigns; // Maintains active campaigns only

    /**
     * @notice Emitted when a new Campaign contract is instantiated
     * @param organisation The beneficiary that is running the campaign
     * @param campaign The address of the newly instantiated Campaign contract
     * @param durationHrs The duration that the campaign will run for
     */
    event MountCampaign(address organisation, address campaign, uint256 durationHrs);

    /**
     * @notice Emitted when a campaign has ended and is closed
     * @param organisation The beneficiary that was in-charge of the campaign
     * @param campaign The address of the closing Campaign contract
     */
    event CampaignEnded(address organisation, address campaign);

    /**
     * @notice Emitted when the commission money in this CampaignFactory contract is withdrawn
     * @param amt The value of the commission withdrawn
     */
    event CommissionWithdrawn(uint256 amt);

    /**
     * @notice Emitted when a campaign contract has been deleted. Used when a campaign or its 
     * managing beneficiary is deemed to be untrustworthy
     * @param organisation The beneficiary that was running the campaign
     * @param campaign The address of the deleted Campaign contract
     */
    event CampaignDeleted(address organisation, address campaign);

    /**
     * @notice Emitted when a beneficiary has been deleted from this contract's orgCampaigns mapping
     * @param organisation The beneficiary that has been deleted
     */
    event OrgDeleted(address organisation);

    /**
     * @notice Emitted when all donations made to an untrustworthy campaign has been refunded, including
     * transferring any unclaimed donations to this CampaignFactory contract
     * @param organisation The beneficiary that was in-charge of the distrusted campaign
     */
    event RefundComplete(address organisation);


    // --- MODIFIERS ---
    modifier ownerOnly() {
        require(owner == msg.sender, "Caller is not owner");
        _;
    }

    modifier verifiedOnly() {
        require(isVerified(msg.sender) == true, "Address is not verified");
        _;
    }


    // --- FUNCIONS ---
    /**
     * @notice Creates a new instance of this CampaignFactory contract
     * @param IAMaddress The address of the IAM contract
     */
    constructor(IAM IAMaddress) public {
        owner = msg.sender;
        IAMContract = IAMaddress;
    }

    /**
     * @notice The receive function for this CampaignFactory contract.
     * @dev Currently only used for receiving commissions from Campaign contracts
     */
    function() payable external {}

    /**
     * @notice Start a new campaign with the default duration of 1 year
     * @dev Has an overloaded function alternative that allows caller to specify a duration for the campaign
     * @return The address of the newly created Campaign contract
     */
    function addCampaign() public verifiedOnly returns (Campaign) {
        require(orgCampaigns[msg.sender].length < MAX_CHARITIES, "Maximum active charities reached");

        uint256 durationSecs = convertHoursToSeconds(HoursInYear);
        Campaign c = new Campaign(durationSecs, msg.sender, IAMContract);
        orgCampaigns[msg.sender].push(address(c));

        emit MountCampaign(msg.sender, address(c), HoursInYear);
        return c;
    }

    /**
     * @notice Start a new campaign with a specified campaign duration in hours
     * @dev Has an overloaded function alternative that uses the default campaign duration of 1 year
     * @return The address of the newly created Campaign contract
     */
    function addCampaign(uint16 durationHrs) public verifiedOnly returns (Campaign) {
        require(durationHrs >= 24, "Minimum duration (hrs) is 24 hour");
        require(durationHrs <= HoursInYear, "Maximum duration (in hrs) is 1 year");
        require(orgCampaigns[msg.sender].length < MAX_CHARITIES, "Maximum active charities reached");

        uint256 durationSecs = convertHoursToSeconds(durationHrs);
        Campaign c = new Campaign(durationSecs, msg.sender, IAMContract);
        orgCampaigns[msg.sender].push(address(c));

        emit MountCampaign(msg.sender, address(c), durationHrs);
        return c;
    }

    /**
     * @notice Closes the campaign that has went past its ending date and time
     * @dev This function must only be called from the closing Campaign contract's withdraw function.
     * This is to ensure that all donations have been transferred to the beneficiary and this 
     * CampaignFactory contract (in the form of commissions)
     * @param organisation The address of the beneficiary running the closing campaign
     * @param campaign The instance of the Campaign contract that is being closed
     */
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
        emit CampaignEnded(organisation, address(campaign));
    }

    /**
     * @notice Allows the manager of this CampaignFactory contract to take out all collected commissions
     * to date
     */
    function withdrawCommissions() public ownerOnly {
        require(address(this).balance > 0, "No remaining balance");
        address payable ownerAddr = address(uint160(owner));
        uint256 amount = address(this).balance;

        ownerAddr.transfer(amount);
        emit CommissionWithdrawn(amount);
    }

    /**
     * @notice Deletes an untrustworthy beneficiary from this contract's orgCampaigns mapping
     * @dev This does not affect the status of the beneficiary in the IAM contract
     * @param organisation The address of the beneficiary that will be deleted from orgCampaigns
     */
    function deleteDistrustedOrg(address organisation) public ownerOnly {
        require(isDistrust(organisation) == true, "Organisation status is not distrust");
        require(block.timestamp >= IAMContract.getRefundPeriod(organisation) + getSecondsInSixMonths(), "Refund period is ongoing");
        uint256 len = orgCampaigns[organisation].length - 1;
        for (int i = int(len); i >= 0; i--) {
            Campaign c = Campaign(orgCampaigns[organisation][uint256(i)]);
            c.returnRemainingBalance();
            deleteCampaignFromMapping(organisation, c);
        }
        deleteOrgFromMapping(organisation);
        emit RefundComplete(organisation);
    }

    /**
     * @notice Deletes the last Campaign contract linked to an organisation in the
     * orgCampaigns mapping
     * @dev This function must be used exclusively in the deleteDistrustedOrg function 
     * as the latter contains logic code to complement the function
     * @param organisation The address of the beneficiary to delete a Campaign contract from
     * @param campaign An address of a Campaign contract that will be deleted
     */
    function deleteCampaignFromMapping(address organisation, Campaign campaign) private {
        orgCampaigns[organisation].pop();
        emit CampaignDeleted(organisation, address(campaign));
    }

    /**
     * @notice Deletes a beneficiary from the orgCampaigns mapping
     * @param organisation The address of the beneficiary to delete
     */
    function deleteOrgFromMapping(address organisation) private {
        delete orgCampaigns[organisation];
        emit OrgDeleted(organisation);
    }

    // VIEWS

    function isVerified(address organisation) public view returns (bool) {
        return IAMContract.isVerified(organisation);
    }

    function isLocked(address organisation) public view returns (bool) {
        return IAMContract.isLocked(organisation);
    }

    function isDistrust(address organisation) public view returns (bool) {
        return IAMContract.isDistrust(organisation);
    }

    function getCampaignsOfOrg(address organisation) public view returns (address[] memory) {
        return orgCampaigns[organisation];
    }

    function convertHoursToSeconds(uint16 hrs) private view returns (uint256) {
        return uint256(SecsInHour  * hrs);
    }

    function getSecondsInSixMonths() private view returns (uint256) {
        return convertHoursToSeconds(HoursInYear) / 2;
    }
}
