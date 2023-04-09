# Themis
 
## Setup
1. Install [NodeJS](https://nodejs.org/en/download/)
2. Install truffle globally
```
npm install truffle -g
```
3. Install [Ganache](https://trufflesuite.com/ganache/)
4. Install dependencies
```
npm i
```

## Refund
When it comes to tracking past donations and initiating a refund, there are several options.
1. Store all donation data in the contracts itself - not scalable
2. Read past transactions on the chain via contract - expensive as the more transactions there are on the chain, the more gas it takes to read through them
3. Read past transactions on chain externally and send data to the contract - both scalable and does not incur gas costs for reading.

You will need to update the donor's address and the campaign's address in the script to use it. This script acts as a proof of concept for a node app's functionalities.