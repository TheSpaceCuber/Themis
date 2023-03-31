// index.js
const Web3 = require('web3');
const contractJSON = require('./build/contracts/HelloWorld.json');
const dotenv = require('dotenv');
dotenv.config();
const web3 = new Web3(process.env.GANACHE_URL);

web3.eth.net.isListening()
    .then(() => console.log("Connected"))
    .catch(e => console.log("Failed to connect: ", e));

const contractABI = contractJSON.abi;
const HelloWorldContract = new web3.eth.Contract(contractABI, process.env.CONTRACT_ADDRESS);
console.log(HelloWorldContract.options.address); // Prints address

const options = {
    fromBlock: 0,
    toBlock: 'latest',
    address: HelloWorldContract.options.address,
};

const setMessageAsync = async (message) => {
    const accounts = await web3.eth.getAccounts();
    const result = await HelloWorldContract.methods.setMessage(message).send({ from: accounts[0] });
    // console.log(result);
};

const getEventsAsync = async () => {
    const events = await HelloWorldContract.getPastEvents('HelloSetMessage', options);
    // TODO: return events and process it
    // console.log(events);
};

setMessageAsync("Hello World!");
getEventsAsync();
