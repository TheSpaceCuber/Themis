// 2_deploy_contracts.js
const HelloWorld = artifacts.require("HelloWorld");
const CampaignFactory = artifacts.require("CampaignFactory");
const IAM = artifacts.require("IAM");

module.exports = function (deployer) {
  let iam;
  deployer.deploy(HelloWorld);
  deployer.deploy(IAM).then(instance => {
    iam = instance;
    // Deploy CampaignFactory contract
    return deployer.deploy(CampaignFactory, iam.address);
    // Do not deploy Campaign here. It should be deployed by CampaignFactory.
  });
};
