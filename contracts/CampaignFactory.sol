pragma solidity ^0.5.17;

import "./Campaign.sol";
import "./IAM.sol";

contract CampaignFactory {
    address owner;
    IAM IAMContract;
    uint8 MAX_CHARITIES = 5;
    uint16 HoursInYear = 8760;
    uint16 SecsInHour = 3600;

    mapping(address => address[]) orgCampaigns;

    event mountCampaign(address organisation, address campaign, uint256 durationHrs);
    event campaignEnded(address organisation, address campaign);
    event commissionWithdrawn(uint256 amnt);
    event campaignDeleted(address organisation, address campaign);
    event orgDeleted(address organisation);
    event refundComplete(address organisation);
    
    constructor(IAM IAMaddress) public {
        owner = msg.sender;
        IAMContract = IAMaddress;
    }

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
        require(durationHrs >= 1, "Minimum duration (hrs) is 1 hour");
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
    
    function refundAllCampaigns(address organisation) public ownerOnly {
        require(isDistrust(organisation) == true, "Organisation status is not distrust");
        uint256 len = orgCampaigns[organisation].length - 1;
        for (int i = int(len); i >= 0; i--) {
            Campaign c = Campaign(orgCampaigns[organisation][uint256(i)]);
            c.refund(address(c)); // placeholder
            deleteCampaignFromMapping(organisation, address(c));
        }
        deleteOrgFromMapping(organisation);
        emit refundComplete(organisation);
    }

    function deleteCampaignFromMapping(address organisation, address campaignAddr) private {
        orgCampaigns[organisation].pop();
        emit campaignDeleted(organisation, campaignAddr);
    }

    function deleteOrgFromMapping(address organisation) private {
        delete orgCampaigns[organisation];
        emit orgDeleted(organisation);
    }
}
