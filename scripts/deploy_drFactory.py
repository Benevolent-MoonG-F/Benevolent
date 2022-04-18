from brownie import (
    BenevolentMoonFactory,
    GovernanceTimeLock,
    DailyRocket,
    MoonSquares,
    BMSGToken,
    MyGovernor,
    RedirectAll,
    accounts,
    config,
    history,
    network,
    convert,
    MoneyHandler,
    interface,
    chain
)
from random import randrange
from scripts.helpful_scripts import get_account
from web3 import Web3, constants


network.priority_fee("1 gwei")
network.max_fee("50 gwei")

MIN_DELAY = 2
host = convert.to_address("0xEB796bdb90fFA0f28255275e16936D25d3418603")
cfa = convert.to_address("0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873")
ida = convert.to_address("0x804348D4960a61f2d5F9ce9103027A3E849E09b8")
DAI = convert.to_address("0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F")
fDaix = convert.to_address("0x06577b0B09e69148A45b866a0dE6643b6caC40Af")
btc_aggregator = convert.to_address("0x007A22900a3B98143368Bd5906f8E17e9867581b")
lending_pool = convert.to_address("0x178113104fEcbcD7fF8669a0150721e231F0FD4B")
aaveToken = convert.to_address("0x639cB7b21ee2161DF9c882483C9D55c90c20Ca3e")
eth_aggregator = convert.to_address("0x0715A7794a1dc8e42615F059dD6e406A6594651A")
matic_aggregator = convert.to_address("0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada")

account = get_account()

link = interface.LinkTokenInterface("0x326C977E6efc84E512bB9C30f76E30c160eD06FB")
dai = interface.IERC20(DAI)
def deploy_fatory():
    factory_contract = (
        BenevolentMoonFactory.deploy({"from": account})
    if len(BenevolentMoonFactory) <=0
    else BenevolentMoonFactory[-1]
    )

def deploy_handler():
    handelr = (
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

def deploy_Daily_contracts(asset, agg, salt):
    bytecode1 = BenevolentMoonFactory[-1].getBytecode(
        1,
        convert.to_string(asset),
        agg,
        MoneyHandler[-1].address,
        1652918400 #midnight utc
        
    )
    tx = BenevolentMoonFactory[-1].deployDailyRocket(
        bytecode1,
        salt,
        asset,
        {"from": account}
    )
    tx.wait(1)

def deploy_Moon_contract(asset, agg, salt):
    bytecode = BenevolentMoonFactory[-1].getBytecode(
        2,
        convert.to_string(asset),
        agg,
        MoneyHandler[-1].address,
        1652918400
    )
    tx = BenevolentMoonFactory[-1].deployMoonSquares(
        bytecode,
        salt,
        asset,
        {"from": account}
    )
    tx.wait(1)

def daily_rokecket():
    address = BenevolentMoonFactory[-1].getDRAddress("BTC")
    drBTC = DailyRocket.at(address)

    link.transfer(
        drBTC.address,
        "1 ether",
        {"from": account}
    )

    print(drBTC.getTime())

def moonsquares():
    address = BenevolentMoonFactory[-1].getMSAddress("BTC")
    msBTC = MoonSquares.at(address)

    link.transfer(
        msBTC.address,
        "1 ether",
        {"from": account}
    )

    print(msBTC.getTime())

def deploy_governance():
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
    #governance_token.delegate(account, {"from": account})
    print(f"Checkpoints: {governance_token.numCheckpoints(account)}")
    governance_time_lock = (
        GovernanceTimeLock.deploy(
            MIN_DELAY,
            [],
            [],
            {"from": account},
            publish_source=config["networks"][network.show_active()].get(
                "verify", True
            ),
        )
        if len(GovernanceTimeLock) <= 0
        else GovernanceTimeLock[-1]
    )
    governor = (
        MyGovernor.deploy(
            governance_token.address,
            governance_time_lock.address,
            #QUORUM_PERCENTAGE,
            #VOTING_PERIOD,
            #VOTING_DELAY,
            {"from": account},
            publish_source=config["networks"][network.show_active()].get("verify", True),
        )
        if len(MyGovernor) <= 0
        else MyGovernor[-1]
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
    drAddress = (
        RedirectAll.deploy(
            host,
            cfa,
            fDaix,
            BMSGToken[-1].address,
            MoneyHandler[-1].address,
            {"from": account},
            #publish_source=True
        )
        if len(RedirectAll) <= 0
        else RedirectAll[-1]
    )


def daily_transactions(index):
    address = BenevolentMoonFactory[-1].getDRAddress("BTC")
    drBTC = DailyRocket.at(address)
    if index ==1:
        account1 = accounts.add(config["wallets"]["from_test1"])
    if index ==2:
        account1 = accounts.add(config["wallets"]["from_test2"])
    elif index ==3:
        account1 = accounts.add(config["wallets"]["from_test3"])
    i = 1
    while i <= 4:
        price = drBTC.getPrice(0)
        prediction = randrange(price, ((price + 9000) or (price - 9000)))
        dai.approve(drBTC.address, "10 ether", {"from":account1})
        drBTC.predictClosePrice(prediction, {"from": account1})
        i+=1


def moon_transactions(index):

    address = BenevolentMoonFactory[-1].getMSAddress("BTC")
    msBTC = MoonSquares.at(address)
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
        market = "BTC"
        dai.approve(msBTC.address, 10000000000000000000, {"from":account1})
        msBTC.predictAsset(prediction, {"from": account1})
        i+=1
def send_transactions():
    i = 1
    while i <= 3:
        moon_transactions(i)
        daily_transactions(i)
        i+=1


def main():
    deploy_handler()
    deploy_fatory()
    deploy_Daily_contracts("ETH", eth_aggregator, 600)
    deploy_Moon_contract("ETH", eth_aggregator, 742)
    deploy_Daily_contracts("MATIC", matic_aggregator, 194)
    deploy_Moon_contract("MATIC",matic_aggregator, 277)
    #daily_rokecket()
    #moonsquares()
    #send_transactions()
    
    
    


if __name__ =='__main__':
    main()