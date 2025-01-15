// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private s_number;

    event Box__NumberChanged(uint256 number);

    constructor() Ownable(msg.sender) {}

    function store(uint256 newNumber) public onlyOwner {
        s_number = newNumber;

        emit Box__NumberChanged(newNumber);
    }

    function getNumber() external view returns (uint256) {
        return s_number;
    }
}
