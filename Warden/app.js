const Web3 = require("web3");
const web3 = new Web3("http://127.0.0.1:7545");
web3.eth.net.isListening()
    .then(() => console.log("Web3 connected"))
    .catch(e => console.log("Web3 failed to connect: ", e));

// Retrieve transaction data
const contractAddress = "0x6419a773597f40e0daB23f845EF43a8733929561";

// // For retrieving contract data
// const abi = [
//     {
//         inputs: [],
//         name: "getMessage",
//         outputs: [{ internalType: "string", name: "", type: "string"}],
//         stateMutability: "view",
//         type: "function",
//     },
// ];

// const helloWorldContract = new web3.eth.Contract(abi, contractAddress);

// helloWorldContract.methods.getMessage().call((error, result) => {
//     if (error) {
//         console.error(error);
//         return;
//     }

//     console.log("Data stored in contract: ", result);
// });


/**
 * This method of looking through the logs is useful for searching through past campaigns that have ended.
 * This method returns all the logs that are related to a specified contract address (i.e. the campaign's contract)
 * and then retrieves transaction information based on the 'transactionHash' field in the logs.
 * 
 * Potentially slow since we're sifting through the entire chain.
 */
const options = {
    fromBlock: 0,
    toBlock: 'latest',
    address: contractAddress,
};

// // Retrieve logs 
// web3.eth.getPastLogs(options).then(function (logs) {
//     logs.forEach(processHash);
// });

// // Get transaction data from transaction hash in logs
// function processHash(log) {
//     // console.log(log);
//     web3.eth.getTransaction(log.transactionHash).then(function (output) {
//         console.log(output);
//     });
// }

/**
 * This other method may be more efficient for refund purposes since we're only looking at events
 * from a particular contract. However, one limitation is that this method requires a contract's
 * ABI, which is some sort of JSON representing the source code. Currently, the simplest but jankiest
 * (i.e. may not be feasible) way to get the ABI is through the .build/contracts/ directory in the 
 * Truffle workspace.
 */
let contractJSON = require('./CampaignTest.json');
let contractABI = contractJSON.abi;

let CampaignTestContract = new web3.eth.Contract(contractABI, contractAddress);

CampaignTestContract.getPastEvents("DonationMade", options, (error, events) => {
    if (error) {
        console.log(error);
    } else {
        console.log(events);
    }
});