// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

import { GovernanceToken } from "../src/GovernanceToken.sol";
import { DaoGovernor } from "../src/DaoGovernor.sol";
import { Treasury } from "../src/Treasury.sol";
import { Box } from "../src/Box.sol";
import { DaoGovernorParams } from "../src/DaoGovernorParams.sol";

contract DeployDAO is Script {
    function run()
        external
        returns (GovernanceToken token, TimelockController timelock, DaoGovernor governor, Treasury treasury, Box box)
    {
        address deployer = msg.sender;

        vm.startBroadcast();

        address[] memory bootstrap = new address[](1);
        bootstrap[0] = deployer;

        timelock = new TimelockController(DaoGovernorParams.TIMELOCK_DELAY_SECONDS, bootstrap, bootstrap, deployer);

        treasury = new Treasury(address(timelock));
        box = new Box(address(timelock));

        token = new GovernanceToken(
            vm.envOr("TEAM_BENEFICIARY", deployer),
            address(treasury),
            vm.envOr("COMMUNITY_WALLET", deployer),
            vm.envOr("LIQUIDITY_WALLET", deployer)
        );

        governor = new DaoGovernor(token, timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.revokeRole(timelock.PROPOSER_ROLE(), deployer);
        timelock.revokeRole(timelock.CANCELLER_ROLE(), deployer);
        timelock.revokeRole(timelock.EXECUTOR_ROLE(), deployer);

        vm.stopBroadcast();
    }
}
