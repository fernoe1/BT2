// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

import { GovernanceToken } from "../src/GovernanceToken.sol";
import { DaoGovernor } from "../src/DaoGovernor.sol";
import { Treasury } from "../src/Treasury.sol";
import { Box } from "../src/Box.sol";
import { TokenVesting } from "../src/TokenVesting.sol";
import { DaoGovernorParams } from "../src/DaoGovernorParams.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { GovernorCountingSimple } from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract DaoGovernanceTest is Test {
    GovernanceToken internal token;
    TimelockController internal timelock;
    DaoGovernor internal governor;
    Treasury internal treasury;
    Box internal box;

    address internal deployer = address(this);
    address internal teamBeneficiary = address(0xBEEF);
    address internal communityWallet = address(0xC0FFEE);
    address internal liquidityWallet = address(0x11C1D);

    uint256 internal constant ALICE_PK = 0xA11CE;
    address internal alice;

    function setUp() public {
        alice = vm.addr(ALICE_PK);

        address[] memory boot = new address[](1);
        boot[0] = deployer;

        timelock = new TimelockController(DaoGovernorParams.TIMELOCK_DELAY_SECONDS, boot, boot, deployer);

        treasury = new Treasury(address(timelock));
        box = new Box(address(timelock));

        token = new GovernanceToken(teamBeneficiary, address(treasury), communityWallet, liquidityWallet);

        governor = new DaoGovernor(token, timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));

        timelock.revokeRole(timelock.PROPOSER_ROLE(), deployer);
        timelock.revokeRole(timelock.CANCELLER_ROLE(), deployer);
        timelock.revokeRole(timelock.EXECUTOR_ROLE(), deployer);

        uint256 aliceShare = IERC20(address(token)).balanceOf(communityWallet) / 2;
        vm.prank(communityWallet);
        token.transfer(alice, aliceShare);

        vm.prank(alice);
        token.delegate(alice);

        vm.roll(block.number + 2);
        vm.warp(block.timestamp + 30);
    }

    function test_mintSplitsMatchAllocation() public {
        address[] memory boot = new address[](1);
        boot[0] = address(this);
        TimelockController tl =
            new TimelockController(DaoGovernorParams.TIMELOCK_DELAY_SECONDS, boot, boot, address(this));
        Treasury tr = new Treasury(address(tl));
        GovernanceToken tk = new GovernanceToken(teamBeneficiary, address(tr), communityWallet, liquidityWallet);

        uint256 initial = DaoGovernorParams.INITIAL_SUPPLY;
        assertEq(tk.totalSupply(), initial);
        assertEq(IERC20(address(tk)).balanceOf(address(tr)), initial * 30 / 100);
        assertEq(IERC20(address(tk)).balanceOf(communityWallet), initial * 20 / 100);
        assertEq(IERC20(address(tk)).balanceOf(liquidityWallet), initial * 10 / 100);
        TokenVesting v = TokenVesting(address(tk.teamVesting()));
        assertEq(IERC20(address(tk)).balanceOf(address(v)), initial * 40 / 100);
    }

    function test_delegationMovesVotingPower() public {
        address bob = address(0xB0B);
        vm.prank(alice);
        token.delegate(bob);

        assertEq(token.getVotes(alice), 0);
        assertEq(token.getVotes(bob), token.balanceOf(alice));
        assertEq(token.delegates(alice), bob);
    }

    function test_pastVotesSnapshotAfterTransfer() public {
        address bob = address(0xB0B02);
        uint256 aliceBefore = token.balanceOf(alice);

        uint256 moved = aliceBefore / 4;
        vm.prank(alice);
        token.transfer(bob, moved);

        uint256 bn = block.number;
        vm.roll(bn + 1);

        assertEq(token.getPastVotes(alice, bn), aliceBefore - moved);
        assertEq(token.getPastVotes(bob, bn), 0);

        vm.prank(bob);
        token.delegate(bob);
        vm.roll(block.number + 2);

        assertEq(token.getVotes(bob), token.balanceOf(bob));
    }

    function test_permitSetsAllowance() public {
        address spender = address(0xDEAD);
        uint256 value = 1_000e18;
        uint256 nonce = token.nonces(alice);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 inner = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                alice,
                spender,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), inner));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PK, digest);
        ERC20Permit(address(token)).permit(alice, spender, value, deadline, v, r, s);

        assertEq(token.allowance(alice, spender), value);
        assertEq(token.nonces(alice), nonce + 1);
    }

    function test_vesting_halfwayReleasesRoughlyHalf() public {
        TokenVesting v = TokenVesting(address(token.teamVesting()));

        vm.warp(block.timestamp + 180 days);

        uint256 beforeBal = IERC20(address(token)).balanceOf(teamBeneficiary);
        v.release();
        uint256 afterBal = IERC20(address(token)).balanceOf(teamBeneficiary);

        uint256 vested = DaoGovernorParams.INITIAL_SUPPLY * 40 / 100;
        assertApproxEqRel(afterBal - beforeBal, vested / 2, 0.02e18);
    }

    function test_vestingFullyVestedReleasesAllocation() public {
        TokenVesting v = TokenVesting(address(token.teamVesting()));

        vm.warp(block.timestamp + 400 days);

        uint256 amt = IERC20(address(token)).balanceOf(address(v));
        v.release();

        assertEq(IERC20(address(token)).balanceOf(teamBeneficiary), amt);
        assertEq(IERC20(address(token)).balanceOf(address(v)), 0);
    }

    function test_votingPowerUsesPastCheckpointAtSnapshotBlock() public {
        uint256 snapBlock = block.number;
        vm.roll(snapBlock + 3);
        assertEq(token.getPastVotes(alice, snapBlock), token.balanceOf(alice));
    }

    function test_treasuryRejectsUnauthorizedWithdraw() public {
        vm.expectRevert(Treasury.TreasuryUnauthorizedCaller.selector);
        treasury.withdrawEther(payable(alice), 1 ether);

        vm.expectRevert(Box.BoxUnauthorizedCaller.selector);
        box.store(1);
    }

    function test_governance_BoxStoreProposalEndToEnd() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(box);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(Box.store.selector, uint256(42));
        string memory description = "Task 3: set box to 42 #42";

        vm.prank(alice);
        uint256 pid = governor.propose(targets, values, calldatas, description);

        assertEq(pid, governor.getProposalId(targets, values, calldatas, keccak256(bytes(description))));

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(alice);
        governor.castVote(pid, uint8(GovernorCountingSimple.VoteType.For));

        vm.roll(block.number + governor.votingPeriod() + 1);

        assertEq(uint256(governor.state(pid)), uint256(IGovernor.ProposalState.Succeeded));

        governor.queue(targets, values, calldatas, keccak256(bytes(description)));
        vm.warp(block.timestamp + DaoGovernorParams.TIMELOCK_DELAY_SECONDS + 1);

        governor.execute{ value: 0 }(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(box.retrieve(), 42);
        assertEq(uint256(governor.state(pid)), uint256(IGovernor.ProposalState.Executed));
    }

    /// One additional quorum assertion: quorum tracks past total supply fraction.
    function test_quorumIsFourPercentOfPastSupply() public view {
        uint256 snap = governor.clock() - 1;
        uint256 q = governor.quorum(snap);
        assertEq(q, token.getPastTotalSupply(snap) * 4 / 100);
    }
}
