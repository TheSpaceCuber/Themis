pragma solidity ^0.5.17;

import "./IAM.sol";
import "./TestCampaign.sol";

/**
 * @title The brains of Themis
 * @author IS4302 Group 11
 * @notice Creates, closes, and manages campaigns
 * @dev This test contract has some minor variations from CampaignFactory.sol to allow for 
 * specific time values to be tested on.
 */
contract TestCampaignFactory {
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


    // --- FUNCTIONS ---
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
    function addCampaign() public verifiedOnly returns (TestCampaign) {
        require(orgCampaigns[msg.sender].length < MAX_CHARITIES, "Maximum active charities reached");

        uint256 durationSecs = hoursToSeconds(HoursInYear);
        TestCampaign c = new TestCampaign(durationSecs, msg.sender, IAMContract);
        orgCampaigns[msg.sender].push(address(c));

        emit mountCampaign(msg.sender, address(c), HoursInYear);
        return c;
    }

    /**
     * @notice Start a new campaign with a specified campaign duration in hours
     * @dev Has an overloaded function alternative that uses the default campaign duration of 1 year
     * @return The address of the newly created Campaign contract
     */
    function addCampaign(uint16 durationHrs) public verifiedOnly returns (TestCampaign) {
        require(durationHrs >= 24, "Minimum duration (hrs) is 24 hour");
        require(durationHrs <= HoursInYear, "Maximum duration (in hrs) is 1 year");
        require(orgCampaigns[msg.sender].length < MAX_CHARITIES, "Maximum active charities reached");

        uint256 durationSecs = hoursToSeconds(durationHrs);
        TestCampaign c = new TestCampaign(durationSecs, msg.sender, IAMContract);
        orgCampaigns[msg.sender].push(address(c));

        emit mountCampaign(msg.sender, address(c), durationHrs);
        return c;
    }

    /**
     * @notice Closes the campaign that has went past its ending date and time
     * @dev This function must only be called from the closing Campaign contract's withdraw function.
     * This is to ensure that all donations have been transferred to the beneficiary and this 
     * CampaignFactory contract (in the form of commissions)
     * @param organisation The address of the beneficiary running the closing campaign
     * @param campaign The instance of the Campaign contract that is being closed
     * @param test_isPastLockout A test parameter to test for Campaign contract expiry with 
     * specific time values
     */
    function closeCampaign(address organisation, TestCampaign campaign, bool test_isPastLockout) public {
        require(isVerified(organisation) == true, "Address is not verified");
        require(test_isPastLockout == true, "Campaign is ongoing");
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

    /**
     * @notice Allows the manager of this CampaignFactory contract to take out all collected commissions
     * to date
     */
    function withdrawCommissions() public ownerOnly {
        require(address(this).balance > 0, "No remaining balance");
        address payable ownerAddr = address(uint160(owner));
        uint256 amount = address(this).balance;

        ownerAddr.transfer(amount);
        emit commissionWithdrawn(amount);
    }

    /**
     * @notice Deletes an untrustworthy beneficiary from this contract's orgCampaigns mapping
     * @dev This does not affect the status of the beneficiary in the IAM contract
     * @param organisation The address of the beneficiary that will be deleted from orgCampaigns
     */
    function deleteDistrustedOrg(address organisation) public ownerOnly {
        require(isDistrust(organisation) == true, "Organisation status is not distrust");
        require(block.timestamp >= IAMContract.getRefundPeriod(organisation) + secondsInSixMonths(), "Refund period is ongoing");
        uint256 len = orgCampaigns[organisation].length - 1;
        for (int i = int(len); i >= 0; i--) {
            TestCampaign c = TestCampaign(orgCampaigns[organisation][uint256(i)]);
            c.returnRemainingBalance();
            deleteCampaignFromMapping(organisation, c);
        }
        deleteOrgFromMapping(organisation);
        emit refundComplete(organisation);
    }

    /**
     * @notice Checks if a beneficiary has the 'Verified' status
     * @param organisation The address representing the beneficiary to check
     * @return true if the beneficiary has a 'Verified' status, false otherwise
     */
    function isVerified(address organisation) public view returns (bool) {
        return IAMContract.isVerified(organisation);
    }

    /**
     * @notice Checks if a beneficiary has a 'Locked' status
     * @param organisation The address representing the beneficiary to check
     * @return true if the beneficiary has a "Locked' status, false otherwise    
     */
    function isLocked(address organisation) public view returns (bool) {
        return IAMContract.isLocked(organisation);
    }

    /**
     * @notice Checks if a beneficiary has a 'Distrust' status
     * @param organisation The address representing the beneficiary to check
     * @return true if the beneficiary has a 'Distrust' status, false otherwise
     */
    function isDistrust(address organisation) public view returns (bool) {
        return IAMContract.isDistrust(organisation);
    }

    /**
     * @notice Gets an array of all active campaigns run by a beneficiary
     * @param organisation The address of the beneficiary to look up
     * @return An array of all active campaigns run by specified beneficiary
     */
    function getCampaignsOfOrg(address organisation) public view returns (address[] memory) {
        return orgCampaigns[organisation];
    }

    /**
     * @notice Deletes the last Campaign contract linked to an organisation in the
     * orgCampaigns mapping
     * @dev This function must be used exclusively in the deleteDistrustedOrg function 
     * as the latter contains logic code to complement the function
     * @param organisation The address of the beneficiary to delete a Campaign contract from
     * @param campaign An address of a Campaign contract that will be deleted
     */
    function deleteCampaignFromMapping(address organisation, TestCampaign campaign) private {
        orgCampaigns[organisation].pop();
        emit campaignDeleted(organisation, address(campaign));
    }

    /**
     * @notice Deletes a beneficiary from the orgCampaigns mapping
     * @param organisation The address of the beneficiary to delete
     */
    function deleteOrgFromMapping(address organisation) private {
        delete orgCampaigns[organisation];
        emit orgDeleted(organisation);
    }

    /**
     * @notice Converts hours to seconds
     * @param hrs Time in hours
     * @return Time in seconds
     */
    function hoursToSeconds(uint16 hrs) private view returns (uint256) {
        return uint256(SecsInHour  * hrs);
    }

    /**
     * @notice Gives the value of 6 months in seconds
     * @return The value of 6 months in seconds
     */
    function secondsInSixMonths() private view returns (uint256) {
        return hoursToSeconds(HoursInYear) / 2;
    }
}
