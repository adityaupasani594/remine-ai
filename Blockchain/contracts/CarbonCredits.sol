// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CarbonCredits {
    // Owner of the contract
    address public owner;

    // Mapping to store carbon credits for each node (address)
    mapping(address => uint256) public carbonCredits;

    // Mapping to check if a node is registered
    mapping(address => bool) public isRegistered;

    // Array to keep track of all registered nodes
    address[] public registeredNodes;

    // Event to log when credits are assigned
    event CreditsAssigned(address indexed node, uint256 amount);

    // Event to log when credits are transferred
    event CreditsTransferred(address indexed from, address indexed to, uint256 amount);

    // Event to log when a node is registered
    event NodeRegistered(address indexed node);

    // Modifier to check if the caller is the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    // Modifier to check if the caller is a registered node
    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "Node not registered");
        _;
    }

    // Constructor to set the owner
    constructor() {
        owner = msg.sender;
    }

    // Function to register a new node
    function registerNode(address node) public {
        require(!isRegistered[node], "Node already registered");
        isRegistered[node] = true;
        registeredNodes.push(node);
        emit NodeRegistered(node);
    }

    // Function to assign carbon credits to a node (only callable by contract owner)
    function assignCredits(address node, uint256 amount) public onlyOwner {
        require(isRegistered[node], "Node not registered");
        carbonCredits[node] += amount;
        emit CreditsAssigned(node, amount);
    }

    // Function to get the carbon credits of a node
    function getCredits(address node) public view returns (uint256) {
        return carbonCredits[node];
    }

    // Function to transfer carbon credits from one node to another
    function transferCredits(address to, uint256 amount) public onlyRegistered {
        require(isRegistered[to], "Recipient node not registered");
        require(carbonCredits[msg.sender] >= amount, "Insufficient credits");

        carbonCredits[msg.sender] -= amount;
        carbonCredits[to] += amount;

        emit CreditsTransferred(msg.sender, to, amount);
    }

    // Function to get the total number of registered nodes
    function getTotalNodes() public view returns (uint256) {
        return registeredNodes.length;
    }

    // Function to get all registered nodes (for admin purposes)
    function getAllNodes() public view returns (address[] memory) {
        return registeredNodes;
    }
}