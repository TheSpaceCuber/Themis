# Themis
## Introduction
Themis is a semi-decentralised charity platform built on the Ethereum blockchain with the aim of providing full
transparency to donors. A key feature of our charity platform is that donated monies will be refunded if a 
charity campaign or beneficiary has been found to be fraudulent. This will hopefully give donors better assurance
that their monies are used for good causes.

This repository contains the proposed foundations for running Themis on the blockchain.

### Application Architecture

![Themis application architecture](docs/images/Themis%20Application%20Architecture.png)

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
