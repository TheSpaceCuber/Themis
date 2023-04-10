pragma solidity ^0.5.17;

import "./IAM.sol";
import "./CampaignFactory.sol";

contract Campaign {
    address payable campaignFactory;
    address owner;
    uint256 endDatetime;
    IAM IAMContract;
    uint256 totalDonated = 0;
    uint256 commissionBP = 1000; // 10% == (1000 / 10,000) basis points
    uint256 basispoints = 10000;

    event campaignInfoRetrieved(address owner, string status, uint256 endDatetime, uint256 totalDonated);
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

    modifier ongoingCampaignOnly() {
        require(isPastLockout() == false, "Campaign has ended");
        _;
    }

    modifier pastLockoutOnly() {
        require(isPastLockout() == true, "Campaign is ongoing");
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
        return block.timestamp >= endDatetime;
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
        emit campaignInfoRetrieved(owner, status, endDatetime, totalDonated);
    }

    function getEndDatetime() public view returns (uint256) {
        return endDatetime;
    }

    function getTotalDonated() public view returns (uint256) {
        return totalDonated;
    }
    
    // --- FUNCTIONS ---
    function donate() public payable verifiedOnly ongoingCampaignOnly {
        require(msg.value > 0, "Invalid donation amount");
        totalDonated += msg.value;
        emit donationMade(msg.sender, msg.value);
    }

    function withdraw() public ownerOnly verifiedOnly pastLockoutOnly {
        uint256 commission = (totalDonated * commissionBP) / basispoints;
        
        address payable campgnFactory = address(uint160(campaignFactory));
        address payable beneficiary = address(uint160(owner));
        uint256 netDonationAmt =  totalDonated - commission;

        campgnFactory.transfer(commission);
        beneficiary.transfer(netDonationAmt);
        emit hasWithdrawn(beneficiary, netDonationAmt);

        CampaignFactory(campaignFactory).closeCampaign(owner, this);
    }
    
    function refund(address payable donor, uint256 amt) public distrustOnly {
        require(amt > 0, "No amount to refund");
        require(msg.sender == donor);
        donor.transfer(amt);
        emit hasRefunded(donor, amt);
    }
}
