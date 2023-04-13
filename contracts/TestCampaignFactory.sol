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

    event MountCampaign(address organisation, address campaign, uint256 durationHrs);
    event CampaignEnded(address organisation, address campaign);
    event CommissionWithdrawn(uint256 amt);
    event CampaignDeleted(address organisation, address campaign);
    event OrgDeleted(address organisation);
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


    // --- FUNCTIONS ---
    constructor(IAM IAMaddress) public {
        owner = msg.sender;
        IAMContract = IAMaddress;
    }

    function() payable external {}

    function addCampaign() public verifiedOnly returns (TestCampaign) {
        require(orgCampaigns[msg.sender].length < MAX_CHARITIES, "Maximum active charities reached");

        uint256 durationSecs = convertHoursToSeconds(HoursInYear);
        TestCampaign c = new TestCampaign(durationSecs, msg.sender, IAMContract);
        orgCampaigns[msg.sender].push(address(c));

        emit MountCampaign(msg.sender, address(c), HoursInYear);
        return c;
    }

    function addCampaign(uint16 durationHrs) public verifiedOnly returns (TestCampaign) {
        require(durationHrs >= 24, "Minimum duration (hrs) is 24 hour");
        require(durationHrs <= HoursInYear, "Maximum duration (in hrs) is 1 year");
        require(orgCampaigns[msg.sender].length < MAX_CHARITIES, "Maximum active charities reached");

        uint256 durationSecs = convertHoursToSeconds(durationHrs);
        TestCampaign c = new TestCampaign(durationSecs, msg.sender, IAMContract);
        orgCampaigns[msg.sender].push(address(c));

        emit MountCampaign(msg.sender, address(c), durationHrs);
        return c;
    }

    /**
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
        emit CampaignEnded(organisation, address(campaign));
    }

    function withdrawCommissions() public ownerOnly {
        require(address(this).balance > 0, "No remaining balance");
        address payable ownerAddr = address(uint160(owner));
        uint256 amount = address(this).balance;

        ownerAddr.transfer(amount);
        emit CommissionWithdrawn(amount);
    }

    function deleteDistrustedOrg(address organisation) public ownerOnly {
        require(isDistrust(organisation) == true, "Organisation status is not distrust");
        require(block.timestamp >= IAMContract.getRefundPeriod(organisation) + getSecondsInSixMonths(), "Refund period is ongoing");
        uint256 len = orgCampaigns[organisation].length - 1;
        for (int i = int(len); i >= 0; i--) {
            TestCampaign c = TestCampaign(orgCampaigns[organisation][uint256(i)]);
            c.returnRemainingBalance();
            deleteCampaignFromMapping(organisation, c);
        }
        deleteOrgFromMapping(organisation);
        emit RefundComplete(organisation);
    }

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

    function deleteCampaignFromMapping(address organisation, TestCampaign campaign) private {
        orgCampaigns[organisation].pop();
        emit CampaignDeleted(organisation, address(campaign));
    }

    function deleteOrgFromMapping(address organisation) private {
        delete orgCampaigns[organisation];
        emit OrgDeleted(organisation);
    }

    function convertHoursToSeconds(uint16 hrs) private view returns (uint256) {
        return uint256(SecsInHour  * hrs);
    }

    function getSecondsInSixMonths() private view returns (uint256) {
        return convertHoursToSeconds(HoursInYear) / 2;
    }
}
