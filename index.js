// index.js
const Web3 = require('web3');
const campaignFactoryJSON = require('./build/contracts/CampaignFactory.json');
const campaignJSON = require('./build/contracts/Campaign.json');
const IAM = require('./build/contracts/IAM.json');
const dotenv = require('dotenv');
dotenv.config();
const web3 = new Web3(process.env.GANACHE_URL);

// attempt to connect
web3.eth.net.isListening()
    .then(() => console.log("Connected"))
    .catch(e => console.log("Failed to connect: ", e));

const campaignFactoryABI = campaignFactoryJSON.abi;
const campaignABI = campaignJSON.abi;
const IAMABI = IAM.abi;

const IAMContract = new web3.eth.Contract(IAMABI, process.env.IAM_ADDRESS);
const campaignFactoryContract = new web3.eth.Contract(campaignFactoryABI, process.env.CAMPAIGN_FACTORY_ADDRESS);

/**
 * Creates a new campaign and adds it to the IAM verified list
 */
const setup = async () => {
    const accounts = await web3.eth.getAccounts();
    // addresses
    const IAMOwnerAddress = accounts[0];
    const organizationAddress = accounts[1]; // the organization that wants to have a campaign
    // add organization to IAM verified list
    await IAMContract.methods.add(organizationAddress).send({ from: IAMOwnerAddress });
    // organization creates a new campaign, should be verified already
    await campaignFactoryContract.methods.addCampaign().send({ from: organizationAddress });
}

// TODO: update this
const generateTransactions = async () => {
    const accounts = await web3.eth.getAccounts();
}

// TODO: update this
const getRefundInfo = async () => {
    const accounts = await web3.eth.getAccounts();
}

// TODO: update this
const insertRefundInfo = async () => {
    const accounts = await web3.eth.getAccounts();
}

setup();