// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title TimeLock Contract
 * @author
 * @notice TimeLock Contract
 * @dev TimeLock Contract
 */
contract TimeLock is TimelockController {
    // minDelay is how long you have to wait before you can execute a proposal
    // proposers are the addresses that can propose a proposal
    // executors are the addresses that can execute a proposal
    //
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}
