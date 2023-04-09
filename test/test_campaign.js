const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
const BigNumber = require('bignumber.js'); // npm install bignumber.js
const oneEth = new BigNumber(1000000000000000000); // 1 eth

var assert = require("assert");
var IAM = artifacts.require("../contracts/IAM.sol");
var Campaign = artifacts.require("../contracts/TestCampaign.sol");
var CampaignFactory = artifacts.require("../contracts/TestCampaignFactory.sol");

contract ("Campaign", function(accounts){
    before( async() => {
        IAMInstance = await IAM.deployed();
        campaignFactoryInstance = await CampaignFactory.deployed();
    });

    // Using emitted events to track status
    it("IAM01-1: Registering of beneficiary [Pass]", async() => {
        let setDist = await IAMInstance.add(accounts[0]);
        // Beneficiary status should be verified upon add
        truffleAssert.eventEmitted(setDist, 'addVerifiedOrg'); 
    });

    // Using getStatus to track status
    it("IAM01-2: Registering of beneficiary [Pass]", async() => {
        let bStatus = await IAMInstance.getStatus(accounts[0]);
        await assert.equal(
            bStatus.toString(),
            1 // This is equal to status.VERIFIED
        );
    });

    it("IAM02: Locking of a beneficiary [Pass]", async() => {
        await IAMInstance.setLocked(accounts[0]);
        let bStatus = await IAMInstance.getStatus(accounts[0]);
        await assert.equal(
            bStatus.toString(),
            2 // status.LOCKED
        );
    });

    it("IAM03: Distrust of a beneficiary [Pass]", async() => {
        await IAMInstance.setDistrust(accounts[0]);
        let bStatus = await IAMInstance.getStatus(accounts[0]);
        await assert.equal(
            bStatus.toString(),
            3 // status.DISTRUST
        );
    });

    it("CAMFAC01: Add campaign while account status not verified. [Pass]", async() => {
        await truffleAssert.reverts(
            campaignFactoryInstance.addCampaign({from: accounts[0]}),
            "Address is not verified"
        );
        await IAMInstance.setLocked(accounts[0]);
        await truffleAssert.reverts(
            campaignFactoryInstance.addCampaign({from: accounts[0]}),
            "Address is not verified"
        );
    });

    let camp1;
    it("CAMFAC02: Create campaign with addCampaign() [Pass]", async() => {
        await IAMInstance.setVerified(accounts[0]);
        let addC = await campaignFactoryInstance.addCampaign({from: accounts[0]});
        // Save campaign address in variable for future test case
        camp1 = await addC['logs'][0]['args'][1];
        truffleAssert.eventEmitted(addC, 'mountCampaign');
    });

    it("CAMFAC03: Create 5 more campaigns with addCampaign() [Fail]", async() => {
        // Create 4 campaign to hit limit
        await campaignFactoryInstance.addCampaign({from: accounts[0]});
        await campaignFactoryInstance.addCampaign({from: accounts[0]});
        await campaignFactoryInstance.addCampaign({from: accounts[0]});
        await campaignFactoryInstance.addCampaign({from: accounts[0]});

        // Creation of 6th campaign should fail
        await truffleAssert.reverts(
            campaignFactoryInstance.addCampaign({from: accounts[0]}),
            "Maximum active charities reached"
        );
    });

    it("CAMFAC04: Create campaign with addCampaign(uint16 durationHrs) [Pass]", async() => {
        await IAMInstance.add(accounts[1]);
        let addC3 = await campaignFactoryInstance.methods['addCampaign(uint16)'](240, {from: accounts[1]});
        truffleAssert.eventEmitted(addC3, 'mountCampaign');
    });

    it("CAMFAC05: Create campaign with addCampaign(uint16 durationHrs) using invalid date [Fail]", async() => {
        // Non uint16 number
        await truffleAssert.fails(
            campaignFactoryInstance.methods['addCampaign(uint16)'](-999, {from: accounts[1]})
        );

        // Over uint16 MAX
        await truffleAssert.fails(
            campaignFactoryInstance.methods['addCampaign(uint16)'](65536, {from: accounts[1]})
        );
        
        // Below min duration
        await truffleAssert.reverts(
            campaignFactoryInstance.methods['addCampaign(uint16)'](1, {from: accounts[1]}),
            "Minimum duration (hrs) is 24 hour"
        );
        
        //Above max duration
        await truffleAssert.reverts(
            campaignFactoryInstance.methods['addCampaign(uint16)'](9000, {from: accounts[1]}),
            "Maximum duration (in hrs) is 1 year"
        );
    });

    it("CAMFAC06: Create 5 more Campaigns with addCampaign(uint16 durationHrs) [Fail]", async() => {
        // Create 4 campaign to hit limit
        await campaignFactoryInstance.methods['addCampaign(uint16)'](240, {from: accounts[1]});
        await campaignFactoryInstance.methods['addCampaign(uint16)'](240, {from: accounts[1]});
        await campaignFactoryInstance.methods['addCampaign(uint16)'](240, {from: accounts[1]});
        await campaignFactoryInstance.methods['addCampaign(uint16)'](240, {from: accounts[1]});

        // Creation of 6th campaign should fail
        await truffleAssert.reverts(
            campaignFactoryInstance.methods['addCampaign(uint16)'](240, {from: accounts[1]}),
            "Maximum active charities reached"
        );
    });
    
    it("CAM01: Donate to campaign [Pass]", async() => {
        await IAMInstance.add(accounts[2]);
        campaignInstance = await Campaign.at(camp1);
        let donate = await campaignInstance.donate(false, {from: accounts[2], value: oneEth});
        truffleAssert.eventEmitted(donate, 'donationMade'); 
    });

    it("CAM02: Donate to campaign with invalid value [Fail]", async() => {
        await truffleAssert.reverts(
            campaignInstance.donate(false, {from: accounts[2], value: 0}),
            "Invalid donation amount"
        );
        
        // Over user's balance
        await truffleAssert.fails(
            campaignInstance.donate(false, {from: accounts[2], value: oneEth.multipliedBy(1000)})
        );
    });

    it("CAM03: Owner withdraw campaign before due date [Fail]", async() => {
        await truffleAssert.reverts(
            campaignInstance.withdraw(false, {from: accounts[0]}),
            "Campaign is ongoing"
        );
    });

    it("CAM04: Not Owner withdraw campaign [Fail]", async() => {
        await truffleAssert.reverts(
            campaignInstance.withdraw(false, {from: accounts[1]}),
            "Caller is not owner"
        );
    });

    it("CAM05: Owner withdraw campaign [Pass]", async() => {
        // Balance casted to Bigint for comparison
        let accBal = await web3.eth.getBalance(accounts[0]);
        accBal = await BigInt(accBal);
        let CFBal = await web3.eth.getBalance(campaignFactoryInstance.address);
        CFBal = await BigInt(CFBal);
        let dAmount = await campaignInstance.getTotalDonated();
        dAmount = await BigInt(dAmount);
        
        let commission = await dAmount / 10n ;
        let netDonationAmt = await dAmount - commission;

        let withdrawn = await campaignInstance.withdraw(true, {from: accounts[0]});
        truffleAssert.eventEmitted(withdrawn, 'hasWithdrawn'); 
        
        let newAccBal = await web3.eth.getBalance(accounts[0]);
        newAccBal = await BigInt(newAccBal);
        let newCFBal = await web3.eth.getBalance(campaignFactoryInstance.address);
        newCFBal = await BigInt(newCFBal);

        await assert.equal(
            (accBal + netDonationAmt) / 100000000000000000n,
            newAccBal / 100000000000000000n
        );

        await assert.equal(
            (CFBal + commission) / 100000000000000000n,
            newCFBal / 100000000000000000n
        );
    });
});