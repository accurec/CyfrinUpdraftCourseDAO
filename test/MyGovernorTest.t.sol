// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "src/MyGovernor.sol";
import {GovToken} from "src/GovToken.sol";
import {Box} from "src/Box.sol";
import {TimeLock} from "src/TimeLock.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    TimeLock timelock;
    GovToken govToken;

    address public USER = makeAddr("user");
    uint256 public constant MINT_AMOUNT_GOV_TOKEN = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour - after a vote passes
    uint256 public constant VOTING_DELAY = 1; // How many blocks until the vote is active
    uint256 public constant VOTING_PERIOD = 50400;
    address[] proposers;
    address[] executors;
    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    function setUp() public {
        vm.startPrank(USER);
        govToken = new GovToken(USER, USER);
        govToken.mint(USER, MINT_AMOUNT_GOV_TOKEN);

        govToken.delegate(USER); // Delegate voting power to ourselves
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "Store 888 in the Box.";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        calldatas.push(encodedFunctionCall);
        values.push(0);
        targets.push(address(box));

        // Propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // View the state
        console.log("Proposal state: ", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal state: ", uint256(governor.state(proposalId)));

        // After proposal starts, we can vote
        string memory reason = "Some test cool reason.";
        uint8 voteWay = 1; // This is going to be translated into "For", meaning "Yes"

        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Queue the TX
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // Execute the TX
        governor.execute(targets, values, calldatas, descriptionHash);

        // Assert
        assertEq(valueToStore, box.getNumber());
    }
}
