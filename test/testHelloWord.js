let assert = require('assert');
let HelloWorld = artifacts.require("HelloWorld")

contract("HelloWorld", function(accounts) {

    it("should initialize with the correct default message", async() => {
        let instance = await HelloWorld.deployed();
        let result = await instance.getMessage();
        assert.equal(result, "Hello World!");
    });

    it("should be able to change the message", async() => {
        let instance = await HelloWorld.deployed();
        await instance.setMessage("Hello World 2!");
        let result = await instance.getMessage();
        assert.equal(result, "Hello World 2!");
    });

});