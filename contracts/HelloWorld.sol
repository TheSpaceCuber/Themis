pragma solidity ^0.5.17;

contract HelloWorld {
    string message;

    event HelloSaid(address saidBy);

    constructor() public {
        message = "Hello World!";
    }

    function setMessage(string memory _message) public {
        message = _message;
        emit HelloSaid(msg.sender);
    }

    function getMessage() public view returns (string memory) {
        return message;
    }
}
