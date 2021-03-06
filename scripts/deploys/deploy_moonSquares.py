from brownie import interface, MoonSquares, DailyRocket, RedirectAll, BMSGToken, GovernanceTimeLock, MyGovernor, config, network, convert
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
    dai = interface.IERC20(DAI)
    link = interface.LinkTokenInterface("0xa36085F69e2889c224210F603D836748e7dC0088")
    account = get_account()
    box = (MoonSquares.deploy(
            host,
            cfa,
            fDaix,
            swapRouter,
            {"from": account},
            publish_source=True
        )
        if len(MoonSquares) <= 0
        else MoonSquares[-1]
    )
    boxAddress = box.address
#    link.transfer(
#        boxAddress,
#        convert.to_uint("10000000000000000000"),
#        {"from": account}
#    )
#    box.getTime()
#    box.addpaymentToken(
#        DAI,
#        {"from": account}
#    )
#    box.addAssetsAndAggregators(
#        convert.to_string("BTC"),
#        convert.to_address("0x6135b13325bfC4B00278B4abC5e20bbce2D6580e"),
#        {"from": account}
#    )
#    box.setMoonPrice(
#        4777468576992,
#        "BTC",
#        {"from": account}
#    )

    dr = (DailyRocket.deploy(
            DAI,
            swapRouter,
            boxAddress,
            {"from": account},
            publish_source=True
        )
        if len(DailyRocket) <= 0
        else DailyRocket[-1]
    )
#    link.transfer(
#        dr.address,
#        convert.to_uint("10000000000000000000"),
#        {"from": account}
#    )
#    dr.addPaymentToken(
#        DAI,
#        {"from": account}
#    )
#
#    dr.addAssetAndAgg(
#        convert.to_string("BTC"),
#        convert.to_address("0x6135b13325bfC4B00278B4abC5e20bbce2D6580e"),
#        {"from": account}
#
#    )

    #dai.approve(boxAddress, 10000000000000000000, {"from":account})
    #governance_token = (
    #    BMSGToken.deploy(
    #        fDaix,
    #        host,
    #        ida,
    #        {"from": account},
    #        publish_source=config["networks"][network.show_active()].get(
    #            "verify", False
    #        ),
    #    )
    #    if len(BMSGToken) <= 0
    #    else BMSGToken[-1]
    #)
    #daoAddress = governance_token.address
    #governance_token.delegate(account, {"from": account})
    #print(f"Checkpoints: {governance_token.numCheckpoints(account)}")
    #governance_time_lock = (
    #    GovernanceTimeLock.deploy(
    #        MIN_DELAY,
    #        [],
    #        [],
    #        {"from": account},
    #        publish_source=config["networks"][network.show_active()].get(
    #            "verify", True
    #        ),
    #    )
    #    if len(GovernanceTimeLock) <= 0
    #    else GovernanceTimeLock[-1]
    #)
    #governor = MyGovernor.deploy(
    #    governance_token.address,
    #    governance_time_lock.address,
    #    #QUORUM_PERCENTAGE,
    #    #VOTING_PERIOD,
    #    #VOTING_DELAY,
    #    {"from": account},
    #    publish_source=config["networks"][network.show_active()].get("verify", True),
    #)
    ## Now, we set the roles...
    ## Multicall would be great here ;)
    #proposer_role = governance_time_lock.PROPOSER_ROLE()
    #executor_role = governance_time_lock.EXECUTOR_ROLE()
    #timelock_admin_role = governance_time_lock.TIMELOCK_ADMIN_ROLE()
    #governance_time_lock.grantRole(proposer_role, governor, {"from": account})
    #governance_time_lock.grantRole(
    #    executor_role, constants.ADDRESS_ZERO, {"from": account}
    #)
    #tx = governance_time_lock.revokeRole(
    #    timelock_admin_role, account, {"from": account}
    #)
    #tx.wait(1)
    daoAddress = convert.to_address("0xF9e4019B27CFb53a91a5B1F8C57C2689c14e2791")
    drAddress = (RedirectAll.deploy(
            host,
            cfa,
            fDaix,
            daoAddress,
            boxAddress,
            {"from": account},
            publish_source=True
        )
        if len(RedirectAll) <= 0
        else RedirectAll[-1]
    )


    #tx = box.transferOwnership(GovernanceTimeLock[-1], {"from": account})
    #tx.wait(1)



if __name__ == '__main__':
    main()