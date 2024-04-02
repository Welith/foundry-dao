// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Token} from "../src/Token.sol";
import {Governor, IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract MyGovernorTest is Test {
    MyGovernor public governor;
    Box public box;
    TimeLock public timelock;
    Token public token;

    address public owner = makeAddr("user");

    uint256 public constant MIN_VOTING_DELAY = 3600;
    uint256 public constant VOTING_DELAY = 7200;
    uint256 public constant VOTING_PERIOD = 50400;
    address[] public executors;
    address[] public proposals;
    uint256[] public values;
    bytes[] public calldatas;
    address[] public targets;

    function setUp() public {
        vm.startPrank(owner);

        token = new Token();
        token.delegate(owner);

        timelock = new TimeLock(MIN_VOTING_DELAY, proposals, executors, owner);
        governor = new MyGovernor(token, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, owner);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithouGovernance() public {
        vm.expectRevert();
        box.store(22);
    }

    function testGovernanceUpdatesBox() public {
        uint256 number = 22;
        string memory description = "store 22";
        bytes memory data = abi.encodeWithSignature("store(uint256)", number);
        values.push(0);
        calldatas.push(data);
        targets.push(address(box));

        // 1. Propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        console.log("State:", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("State:", uint256(governor.state(proposalId)));

        // 2. Vote
        string memory reason = "we want to update!";
        uint8 voteWay = 1;

        vm.prank(owner);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the tx
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_VOTING_DELAY + 1);
        vm.roll(block.number + MIN_VOTING_DELAY + 1);

        // 4. Execute
        governor.execute(targets, values, calldatas, descriptionHash);

        console.log("number", box.readNumber());
        assert(box.readNumber() == number);
    }
}
