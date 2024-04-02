// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    constructor(uint256 minDelay, address[] memory proposals, address[] memory executors, address admin)
        TimelockController(minDelay, proposals, executors, msg.sender)
    {}
}
