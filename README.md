# Themis
## Introduction
Themis is a semi-decentralised charity platform built on the Ethereum blockchain with the aim of providing full
transparency to donors. A key feature of our charity platform is that donated monies will be refunded if a 
charity campaign or beneficiary has been found to be fraudulent. This will hopefully give donors better assurance
that their monies are used for good causes.

This repository contains the proposed foundations for running Themis on the blockchain.

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
5. Create a .env file with the following variables
```sh
GANACHE_URL=http://localhost:7545
IAM_ADDRESS=
CAMPAIGN_FACTORY_ADDRESS=
```