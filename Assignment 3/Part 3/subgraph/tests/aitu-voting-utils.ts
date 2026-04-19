import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
  Approval,
  ElectionCreated,
  ElectionStopped,
  OwnershipTransferred,
  Transfer,
  Voted
} from "../generated/AITUVoting/AITUVoting"

export function createApprovalEvent(
  owner: Address,
  spender: Address,
  value: BigInt
): Approval {
  let approvalEvent = changetype<Approval>(newMockEvent())

  approvalEvent.parameters = new Array()

  approvalEvent.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("spender", ethereum.Value.fromAddress(spender))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return approvalEvent
}

export function createElectionCreatedEvent(
  electionId: BigInt,
  name: string,
  creator: Address
): ElectionCreated {
  let electionCreatedEvent = changetype<ElectionCreated>(newMockEvent())

  electionCreatedEvent.parameters = new Array()

  electionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "electionId",
      ethereum.Value.fromUnsignedBigInt(electionId)
    )
  )
  electionCreatedEvent.parameters.push(
    new ethereum.EventParam("name", ethereum.Value.fromString(name))
  )
  electionCreatedEvent.parameters.push(
    new ethereum.EventParam("creator", ethereum.Value.fromAddress(creator))
  )

  return electionCreatedEvent
}

export function createElectionStoppedEvent(
  electionId: BigInt
): ElectionStopped {
  let electionStoppedEvent = changetype<ElectionStopped>(newMockEvent())

  electionStoppedEvent.parameters = new Array()

  electionStoppedEvent.parameters.push(
    new ethereum.EventParam(
      "electionId",
      ethereum.Value.fromUnsignedBigInt(electionId)
    )
  )

  return electionStoppedEvent
}

export function createOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): OwnershipTransferred {
  let ownershipTransferredEvent =
    changetype<OwnershipTransferred>(newMockEvent())

  ownershipTransferredEvent.parameters = new Array()

  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return ownershipTransferredEvent
}

export function createTransferEvent(
  from: Address,
  to: Address,
  value: BigInt
): Transfer {
  let transferEvent = changetype<Transfer>(newMockEvent())

  transferEvent.parameters = new Array()

  transferEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return transferEvent
}

export function createVotedEvent(
  electionId: BigInt,
  candidateId: BigInt,
  emailHash: Bytes
): Voted {
  let votedEvent = changetype<Voted>(newMockEvent())

  votedEvent.parameters = new Array()

  votedEvent.parameters.push(
    new ethereum.EventParam(
      "electionId",
      ethereum.Value.fromUnsignedBigInt(electionId)
    )
  )
  votedEvent.parameters.push(
    new ethereum.EventParam(
      "candidateId",
      ethereum.Value.fromUnsignedBigInt(candidateId)
    )
  )
  votedEvent.parameters.push(
    new ethereum.EventParam(
      "emailHash",
      ethereum.Value.fromFixedBytes(emailHash)
    )
  )

  return votedEvent
}
