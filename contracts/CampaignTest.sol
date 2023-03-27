pragma solidity ^0.5.17;

// This contract is solely for testing purposes

contract CampaignTest {
    address beneficiaryAddr;

    event DonationMade(uint256 amt, address donor);

    constructor(address newBeneficiaryAddr) public {
        beneficiaryAddr = newBeneficiaryAddr;
    }

    function donate(uint256 amt) public payable {
        require(amt > 0, "You can't donate nothing");
        
        emit DonationMade(amt, msg.sender);
    }
}