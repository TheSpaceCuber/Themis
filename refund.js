// index.js
const Web3 = require('web3');
const campaignJSON = require('./build/contracts/Campaign.json');
const dotenv = require('dotenv');

// config
dotenv.config();
const web3 = new Web3('http://localhost:7545');
web3.eth.net.isListening()
    .then(() => console.log("Connected"))
    .catch(e => console.log("Failed to connect: ", e));


// update this
const campaignAddress = '0xFe8b3A231474a7d979AD36Cc30eD8f079bf3B9A7';
const donorAdd = '0x82cbA54247381a4c18b2299dbF08251db9309a37'

const campaignABI = campaignJSON.abi;
const CampaignContract = new web3.eth.Contract(campaignABI, campaignAddress);

const campaignOptions = {
    fromBlock: 0,
    toBlock: 'latest',
    address: CampaignContract.options.address,
};

const simulateRefund = async (userAdd) => {
    const events = await CampaignContract.getPastEvents('donationMade', campaignOptions);
    let amtToRefund = 0;
    for (const event of events) {
        if (event.returnValues.donor == userAdd) {
            amtToRefund += parseInt(event.returnValues.donatedAmt);
        }
    }
    // need to convert to string 
    // https://docs.ethers.org/v5/troubleshooting/errors/#help-NUMERIC_FAULT-overflow
    amtToRefund = amtToRefund.toString();
    // invoke refund, campaign has to be distrust first
    const refundTransaction = await CampaignContract.methods.refund(donorAdd, amtToRefund).send({ from: donorAdd })
    console.log(refundTransaction)
};

simulateRefund(donorAdd);