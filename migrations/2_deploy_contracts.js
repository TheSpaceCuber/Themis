// 2_deploy_contracts.js
const CampaignFactory = artifacts.require("TestCampaignFactory");
const IAM = artifacts.require("IAM");

module.exports = (deployer, network, accounts) => {
  let iam;
  deployer.deploy(IAM).then(instance => {
    iam = instance;
    // Deploy CampaignFactory contract
    return deployer.deploy(CampaignFactory, iam.address);
    // Do not deploy Campaign here. It should be deployed by CampaignFactory.
  });
};
