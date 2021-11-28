
#This scripts are meant to show the how the governance contracts willget used to
#manage the moonSquares contract with an example of ading a new payment Token

from scripts.helpful_scripts import LOCAL_BLOCKCHAIN_ENVIRONMENTS, get_account
from brownie import (
    MyGovernor,
    BMSGToken,
    GovernanceTimeLock,
    MoonSquares,
    Contract,
    config,
    network,
    accounts,
    chain,
)
from web3 import Web3, constants

# Governor Contract
QUORUM_PERCENTAGE = 4
# VOTING_PERIOD = 45818  # 1 week - more traditional.
# You might have different periods for different kinds of proposals
VOTING_PERIOD = 5  # 5 blocks
VOTING_DELAY = 1  # 1 block

# Timelock
# MIN_DELAY = 3600  # 1 hour - more traditional
MIN_DELAY = 1  # 1 seconds

# Proposal
PROPOSAL_DESCRIPTION = "Proposal #1: add a new payment token to the protocol!"
TOKEN_ADDRESS = 0x15F0Ca26781C3852f8166eD2ebce5D18265cceb7

fDaix = 0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f
host = 0xEB796bdb90fFA0f28255275e16936D25d3418603
ida = 0x804348D4960a61f2d5F9ce9103027A3E849E09b8
cfa = 0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873


def deploy_governor():
    account = get_account()
    governance_token = (
        BMSGToken.deploy(
            fDaix,
            host,                ida,
            {"from": account},
            publish_source=config["networks"][network.show_active()].get(
                "verify", False
            ),
        )
        if len(BMSGToken) <= 0
        else BMSGToken[-1]
    )
    governance_token.delegate(account, {"from": account})
    print(f"Checkpoints: {governance_token.numCheckpoints(account)}")
    governance_time_lock = governance_time_lock = (
        GovernanceTimeLock.deploy(
            MIN_DELAY,
            [],
            [],
            {"from": account},
            publish_source=config["networks"][network.show_active()].get(
                "verify", False
            ),
        )
        if len(GovernanceTimeLock) <= 0
        else GovernanceTimeLock[-1]
    )
    governor = MyGovernor.deploy(
        governance_token.address,
        governance_time_lock.address,
        #QUORUM_PERCENTAGE,
        #VOTING_PERIOD,
        #VOTING_DELAY,
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )
    # Now, we set the roles...
    # Multicall would be great here ;)
    proposer_role = governance_time_lock.PROPOSER_ROLE()
    executor_role = governance_time_lock.EXECUTOR_ROLE()
    timelock_admin_role = governance_time_lock.TIMELOCK_ADMIN_ROLE()
    governance_time_lock.grantRole(proposer_role, governor, {"from": account})
    governance_time_lock.grantRole(
        executor_role, constants.ADDRESS_ZERO, {"from": account}
    )
    tx = governance_time_lock.revokeRole(
        timelock_admin_role, account, {"from": account}
    )
    tx.wait(1)
    # Guess what? Now you can't do anything!
    # governance_time_lock.grantRole(timelock_admin_role, account, {"from": account})


def deloyMoonSquares():
    account = get_account()
    box = MoonSquares.deploy(
        host,
        cfa,
        fDaix,
        {"from": account}
    )
    tx = box.transferOwnership(GovernanceTimeLock[-1], {"from": account})
    tx.wait(1)


def propose(store_value):
    account = get_account()
    # We are going to store the number 1
    # With more args, just add commas and the items
    # This is a tuple
    # If no arguments, use `eth_utils.to_bytes(hexstr="0x")`
    args = (store_value,)
    # We could do this next line with just the Box object
    # But this is to show it can be any function with any contract
    # With any arguments
    encoded_function = Contract.from_abi("MoonSquares", MoonSquares[-1], MoonSquares.abi).addpaymentToken.encode_input(
        *args
    )
    print(encoded_function)
    propose_tx = MyGovernor[-1].propose(
        [MoonSquares[-1].address],
        [0],
        [encoded_function],
        PROPOSAL_DESCRIPTION,
        {"from": account},
    )
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        tx = account.transfer(accounts[0], "0 ether")
        tx.wait(1)
    propose_tx.wait(2)  # We wait 2 blocks to include the voting delay
    # This will return the proposal ID
    print(f"Proposal state {MyGovernor[-1].state(propose_tx.return_value)}")
    print(
        f"Proposal snapshot {MyGovernor[-1].proposalSnapshot(propose_tx.return_value)}"
    )
    print(
        f"Proposal deadline {MyGovernor[-1].proposalDeadline(propose_tx.return_value)}"
    )
    return propose_tx.return_value


# Can be done through a UI
def vote(proposal_id: int, vote: int):
    # 0 = Against, 1 = For, 2 = Abstain for this example
    # you can all the #COUNTING_MODE() function to see how to vote otherwise
    print(f"voting yes on {proposal_id}")
    account = get_account()
    tx = MyGovernor[-1].castVoteWithReason(
        proposal_id, vote, "Cuz I lika do da cha cha", {"from": account}
    )
    tx.wait(1)
    print(tx.events["VoteCast"])


def queue_and_execute(store_value):
    account = get_account()
    # time.sleep(VOTING_PERIOD + 1)
    # we need to explicity give it everything, including the description hash
    # it gets the proposal id like so:
    # uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);
    # It's nearlly exactly the same as the `propose` function, but we hash the description
    args = (store_value,)
    encoded_function = Contract.from_abi("MoonSquares", MoonSquares[-1], MoonSquares.abi).addpaymentToken.encode_input(
        *args
    )
    # this is the same as ethers.utils.id(description)
    description_hash = Web3.keccak(text=PROPOSAL_DESCRIPTION).hex()
    tx = MyGovernor[-1].queue(
        [MoonSquares[-1].address],
        [0],
        [encoded_function],
        description_hash,
        {"from": account},
    )
    tx.wait(1)
    tx = MyGovernor[-1].execute(
        [MoonSquares[-1].address],
        [0],
        [encoded_function],
        description_hash,
        {"from": account},
    )
    tx.wait(1)
    print(MoonSquares[-1].retrieve())


def move_blocks(amount):
    for block in range(amount):
        get_account().transfer(get_account(), "0 ether")
    print(chain.height)


def main():
    deploy_governor()
    deloyMoonSquares()
    proposal_id = propose(TOKEN_ADDRESS)
    print(f"Proposal ID {proposal_id}")
    # We do this just to move the blocks along
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        move_blocks(1)
    vote(proposal_id, 1)
    # Once the voting period is over,
    # if quorum was reached (enough voting power participated)
    # and the majority voted in favor, the proposal is
    # considered successful and can proceed to be executed.
    # To execute we must first `queue` it to pass the timelock
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        move_blocks(VOTING_PERIOD)
    # States: {Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed }
    print(f" This proposal is currently {MyGovernor[-1].state(proposal_id)}")
    queue_and_execute(TOKEN_ADDRESS)
