const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");

var assert = require("assert");
var IAM = artifacts.require("../contracts/IAM.sol");
var CampaignFactory = artifacts.require("../contracts/CampaignFactory.sol");

contract ("Campaign", function(accounts){
    before( async() => {
        IAMInstance = await IAM.deployed();
        campaignFactoryInstance = await CampaignFactory.deployed();
    });
    
    console.log("Testing IAM contract");
    
    // Using emitted logs to track status
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
        let setLock = await IAMInstance.setLocked(accounts[0]);
        let bStatus = await IAMInstance.getStatus(accounts[0]);
        await assert.equal(
            bStatus.toString(),
            2 // status.LOCKED
        );
    });

    it("IAM03: Distrust of a beneficiary [Pass]", async() => {
        let setDist = await IAMInstance.setDistrust(accounts[0]);
        let bStatus = await IAMInstance.getStatus(accounts[0]);
        await assert.equal(
            bStatus.toString(),
            3 // status.DISTRUST
        );
    });

    console.log("Testing CampaignFactory contract");

    it("CAMF01: Create Campaign with addCampaign() [Pass]", async() => {
        await IAMInstance.setVerified(accounts[0]);
        let addC = await campaignFactoryInstance.addCampaign({from: accounts[0]});
        truffleAssert.eventEmitted(addC, 'mountCampaign');
    });

    it("CAMF02: Create 5 more campaigns with addCampaign() [Fail]", async() => {
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

    it("CAMF03: Create campaign with addCampaign(uint16 durationHrs) [Pass]", async() => {
        await IAMInstance.add(accounts[1]);
        let addC3 = await campaignFactoryInstance.methods['addCampaign(uint16)'](240, {from: accounts[1]});
        truffleAssert.eventEmitted(addC3, 'mountCampaign');
    });

    it("CAMF04: Create campaign with addCampaign(uint16 durationHrs) using invalid date [Fail]", async() => {
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

    it("CAMF05: Create 5 more Campaigns with addCampaign(uint16 durationHrs) [Fail]", async() => {
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

    console.log("Testing Campaign contract");

    it("CAM01: Donate to campaign [Pass]", async() => {
    });

    it("CAM02: Donate to campaign with invalid value [Fail]", async() => {
    });

    it("CAM03: Owner withdraw campaign before due date [Fail]", async() => {
    });

    it("CAM04: Not Owner withdraw campaign [Fail]", async() => {
    });

    it("CAM05: Owner withdraw campaign [Pass]", async() => {
    });
});