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
    chain,
    network,
    BenevolentMoonFactory
)
from scripts.helpful_scripts import get_account
from web3 import Web3, constants

network.max_fee("100 gwei")
network.priority_fee("1 gwei")
account = get_account()

host = convert.to_address("0xEB796bdb90fFA0f28255275e16936D25d3418603")
cfa = convert.to_address("0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873")
ida = convert.to_address("0x804348D4960a61f2d5F9ce9103027A3E849E09b8")
DAI = convert.to_address("0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F")
fDaix = convert.to_address("0x06577b0B09e69148A45b866a0dE6643b6caC40Af")
btc_aggregator = convert.to_address("0x007A22900a3B98143368Bd5906f8E17e9867581b")
lending_pool = convert.to_address("0x178113104fEcbcD7fF8669a0150721e231F0FD4B")
aaveToken = convert.to_address("0x639cB7b21ee2161DF9c882483C9D55c90c20Ca3e")


fDaixk = convert.to_address("0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09")
host_k = convert.to_address("0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3")
ida_k = convert.to_address("0x556ba0b3296027Dd7BCEb603aE53dEc3Ac283d2b")
cfa_k = convert.to_address("0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F")
#swapRouter =convert.to_address("0xE592427A0AEce92De3Edee1F18E0157C05861564")
DAI_k = convert.to_address("0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD")
btc_aggregator_k = convert.to_address("0x6135b13325bfC4B00278B4abC5e20bbce2D6580e")
lending_pool_k = convert.to_address("0x88757f2f99175387aB4C6a4b3067c77A695b0349")
_aaveToken_k = convert.to_address("0xdCf0aF9e59C002FA3AA091a46196b37530FD48a8")
eth_aggregator = convert.to_address("0x0715A7794a1dc8e42615F059dD6e406A6594651A")
matic_aggregator = convert.to_address("0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada")

MIN_DELAY = 1

def main():
    moonsquare("MATIC", matic_aggregator)



def moonsquare(asset, agg):
    dai = interface.IERC20(DAI)
    print("loading dai and link Interfaces...")
    link = interface.LinkTokenInterface("0x326C977E6efc84E512bB9C30f76E30c160eD06FB")# 0xa36085F69e2889c224210F603D836748e7dC0088
    account = get_account()
    print("deploying moonsquare contract..")

    factory_contract = (
        BenevolentMoonFactory.deploy({"from": account})
    if len(BenevolentMoonFactory) <=0
    else BenevolentMoonFactory[-1]
    )

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
            factory_contract.address,
            {"from": account},
            #publish_source=True
        )
        #if len(MoonSquares) <= 0
        #else MoonSquares[-1]
    )
    boxAddress = box.address
    handler.addContract(boxAddress, {"from": account})
    print("tranfering link to moonSquare contract...")
    #link.transfer(
    #    boxAddress,
    #    convert.to_uint("1 ether"),
    #    {"from": account}
    #)
    print("checking chainlnk aggregator")
    print(box.getTime())
    print("setting moon Price...")
    box.setMoonPrice(
        2,
        {"from": account}
    )
#

    print("depploying Daily Rokect contract")
    dr = (
        DailyRocket.deploy(
            asset,
            agg,
            hander_address,
            1650412800,
            factory_contract.address,
            {"from": account},
            #publish_source=True
        )
        #if len(DailyRocket) <= 0
        #else DailyRocket[-1]
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

#
#
#    def moon_transactions(index):
#        if index ==1:
#            account1 = accounts.add(config["wallets"]["from_test1"])
#        if index ==2:
#            account1 = accounts.add(config["wallets"]["from_test2"])
#        elif index ==3:
#            account1 = accounts.add(config["wallets"]["from_test3"])
#        #dai.transfer(account1, 1000000000000000000000, {"from": account})
#        i = 1
#        while i <= 4:
#            time = chain.time()
#            prediction = randrange(time, (time + 84000))
#            dai.approve(boxAddress, 10000000000000000000, {"from":account1})
#            box.predictAsset(prediction, {"from": account1})
#            price = dr.getPrice()
#            prediction = randrange(price, ((price + 9000) or (price - 9000)))
#            dai.approve(dr.address, "10 ether", {"from":account1})
#            dr.predictClosePrice(prediction, {"from": account1})
#            i+=1
#    i = 1
#    while i <= 3:
#        moon_transactions(i)
#        i+=1
    
       #tx = box.transferOwnership(GovernanceTimeLock[-1], {"from": account})
    #tx.wait(1)



if __name__ == '__main__':
    main()