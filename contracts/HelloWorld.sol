pragma solidity ^0.5.17;

contract HelloWorld {
    string message;

    constructor() public {
        message = "Hello World!";
    }

    function setMessage(string memory _message) public {
        message = _message;
    }

    function getMessage() public view returns (string memory) {
        return message;
    }
}
