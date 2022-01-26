from brownie import MoonSquares, DailyRocket, RedirectAll, BMSGToken, GovernanceTimeLock, MyGovernor, config, network, convert
from scripts.helpful_scripts import get_account
from web3 import Web3, constants


fDaix = convert.to_address("0xe3cb950cb164a31c66e32c320a800d477019dcff")
host = convert.to_address("0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3")
ida = convert.to_address("0x556ba0b3296027Dd7BCEb603aE53dEc3Ac283d2b")
cfa = convert.to_address("0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F")
swapRouter =convert.to_address("0xE592427A0AEce92De3Edee1F18E0157C05861564")
DAI = convert.to_address("0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD")

MIN_DELAY = 1

def main():
    moonsquare()

def moonsquare():
    account = get_account()
    box = MoonSquares.deploy(
        host,
        cfa,
        fDaix,
        swapRouter,
        {"from": account}
    )
    boxAddress = box.address

    dr = DailyRocket.deploy(
        DAI,
        swapRouter,
        boxAddress,
        {"from": account}
    )

    governance_token = (
        BMSGToken.deploy(
            fDaix,
            host,
            ida,
            {"from": account},
            publish_source=config["networks"][network.show_active()].get(
                "verify", False
            ),
        )
        if len(BMSGToken) <= 0
        else BMSGToken[-1]
    )
    daoAddress = governance_token.address
    governance_token.delegate(account, {"from": account})
    print(f"Checkpoints: {governance_token.numCheckpoints(account)}")
    governance_time_lock = (
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

    drAddress = RedirectAll.deploy(
        host,
        cfa,
        fDaix,
        daoAddress,
        boxAddress,
        {"from": account}
    )
    #tx = box.transferOwnership(GovernanceTimeLock[-1], {"from": account})
    #tx.wait(1)



if __name__ == '__main__':
    main()