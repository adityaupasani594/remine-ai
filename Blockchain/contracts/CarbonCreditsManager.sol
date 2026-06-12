pragma solidity ^0.8.19;

import "./CarbonCredits.sol";

contract CarbonCreditsManager {
    CarbonCredits public carbonCreditsContract;

    constructor(address _carbonCreditsContract) {
        carbonCreditsContract = CarbonCredits(_carbonCreditsContract);
    }

    // Function to register a node through the manager
    function registerNode(address node) public {
        carbonCreditsContract.registerNode(node);
    }

    // Function to assign credits through the manager
    function assignCredits(address node, uint256 amount) public {
        carbonCreditsContract.assignCredits(node, amount);
    }

    // Function to get credits through the manager
    function getCredits(address node) public view returns (uint256) {
        return carbonCreditsContract.getCredits(node);
    }

    // Function to transfer credits through the manager
    function transferCredits(address to, uint256 amount) public {
        carbonCreditsContract.transferCredits(to, amount);
    }
}