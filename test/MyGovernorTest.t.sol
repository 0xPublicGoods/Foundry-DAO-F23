// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * Imports
 */
import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    TimeLock timelock;
    GovToken govToken;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 1000 ether;

    uint256 public constant MIN_DELAY = 3600; // HOW MANY SECONDS UNTIL A PROPOSAL CAN BE EXECUTED
    uint256 public constant VOTING_DELAY = 1; // HOW MANY BLOCKS UNTIL A VOTE IS ACTIVE [1 DAY I THINK]
    uint256 public constant VOTING_PERIOD = 50400; // 1 WEEK
    // uint256 public constant QUORUM = 69e18;

    address[] proposers;
    address[] executors;
    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(governor));
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

        string memory description = "Store 888 in Box";

        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        // populate proposal
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // View the State of the Proposal
        console.log("Proposal State: %s", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State: %s", uint256(governor.state(proposalId)));

        // 2. vote
        string memory reason = "I like it";

        uint8 voteWay = 1; // 1 = yes, 2 = no, 3 = abstain
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. queue the tx
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. execute the tx
        governor.execute(targets, values, calldatas, descriptionHash);

        console.log("Box Value: %s", box.getNumber());
        assert(box.getNumber() == valueToStore);
    }
}
