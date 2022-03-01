from random import random, randrange
from re import M
from brownie import (
    interface,
    MoneyHandler,
    MoonSquares,
    DailyRocket,
    RedirectAll,
    BMSGToken,
    GovernanceTimeLock,
    MyGovernor,
    config,
    network,
    convert,
    accounts,
    chain
)
from scripts.helpful_scripts import get_account
from web3 import Web3, constants


fDaix = convert.to_address("0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09")
host = convert.to_address("0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3")
ida = convert.to_address("0x556ba0b3296027Dd7BCEb603aE53dEc3Ac283d2b")
cfa = convert.to_address("0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F")
#swapRouter =convert.to_address("0xE592427A0AEce92De3Edee1F18E0157C05861564")
DAI = convert.to_address("0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD")
btc_aggregator = convert.to_address("0x6135b13325bfC4B00278B4abC5e20bbce2D6580e")
MIN_DELAY = 1

def main():
    moonsquare("BTC", btc_aggregator)




def moonsquare(asset, agg):
    dai = interface.IERC20(DAI)
    print("loading dai and link Interfaces...")
    link = interface.LinkTokenInterface("0xa36085F69e2889c224210F603D836748e7dC0088")
    account = get_account()
    print("deploying moonsquare contract..")
    handler = (
        MoneyHandler.deploy(
            host,
            cfa,
            fDaix,
            DAI,
            {"from": account}
        )
        if len(MoneyHandler) <= 0
        else MoneyHandler[-1]
    )
    hander_address = handler.address
    box = (
        MoonSquares.deploy(
            asset,
            agg,
            hander_address,
            {"from": account},
            publish_source=True
        )
        if len(MoonSquares) <= 0
        else MoonSquares[-1]
    )
    boxAddress = box.address
    #handler.addContract(boxAddress, {"from": account})
    print("tranfering link to moonSquare contract...")
    #link.transfer(
    #    boxAddress,
    #    convert.to_uint("1 ether"),
    #    {"from": account}
    #)
    print("checking chainlnk aggregator")
    print(box.getTime())
    print("setting moon Price...")
    #box.setMoonPrice(
    #    47774,
    #    {"from": account}
    #)
#

    print("depploying Daily Rokect contract")
    dr = (
        DailyRocket.deploy(
            asset,
            agg,
            hander_address,
            {"from": account},
            publish_source=True
        )
        if len(DailyRocket) <= 0
        else DailyRocket[-1]
    )
    handler.addContract(dr.address, {"from": account})
    print("tranfering link to DR contract...")
    #link.transfer(
    #    dr.address,
    #    convert.to_uint("1000000000000000000"),
    #    {"from": account}
    #)
    print(f"time is {dr.getTime()}")
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
    ##governance_token.delegate(account, {"from": account})
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
    #governor = (
    #    MyGovernor.deploy(
    #        governance_token.address,
    #        governance_time_lock.address,
    #        #QUORUM_PERCENTAGE,
    #        #VOTING_PERIOD,
    #        #VOTING_DELAY,
    #        {"from": account},
    #        publish_source=config["networks"][network.show_active()].get("verify", True),
    #    )
    #    if len(MyGovernor) <= 0
    #    else MyGovernor[-1]
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
    #daoAddress = convert.to_address("0xF9e4019B27CFb53a91a5B1F8C57C2689c14e2791")
    #drAddress = (
    #    RedirectAll.deploy(
    #        host,
    #        cfa,
    #        fDaix,
    #        daoAddress,
    #        boxAddress,
    #        {"from": account},
    #        #publish_source=True
    #    )
    #    if len(RedirectAll) <= 0
    #    else RedirectAll[-1]
    #)



    def moon_transactions(index):
        if index ==1:
            account1 = accounts.add(config["wallets"]["from_test1"])
        if index ==2:
            account1 = accounts.add(config["wallets"]["from_test2"])
        elif index ==3:
            account1 = accounts.add(config["wallets"]["from_test3"])
        i = 1
        while i <= 4:
            time = chain.time()
            prediction = randrange(time, (time + 84000))
            dai.approve(boxAddress, 10000000000000000000, {"from":account1})
            box.predictAsset(prediction, {"from": account1})
            i+=1



    def daily_transactions(index):
        if index ==1:
            account1 = accounts.add(config["wallets"]["from_test1"])
        if index ==2:
            account1 = accounts.add(config["wallets"]["from_test2"])
        elif index ==3:
            account1 = accounts.add(config["wallets"]["from_test3"])
        i = 1
        while i <= 4:
            price = dr.getPrice()
            prediction = randrange(price, ((price + 9000) or (price - 9000)))
            dai.approve(dr.address, "10 ether", {"from":account1})
            dr.predictClosePrice(prediction, {"from": account1})
            i+=1
    i = 1
    while i <= 3:
        moon_transactions(i)
        daily_transactions(i)
        i+=1
    
       #tx = box.transferOwnership(GovernanceTimeLock[-1], {"from": account})
    tx.wait(1)



if __name__ == '__main__':
    main()