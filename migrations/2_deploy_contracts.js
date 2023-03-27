const HelloWorld = artifacts.require("HelloWorld");
const CampaignTest = artifacts.require("CampaignTest");

module.exports = function (deployer, network, accounts) {
  deployer.deploy(HelloWorld);
  deployer.deploy(CampaignTest, accounts[1]);
};