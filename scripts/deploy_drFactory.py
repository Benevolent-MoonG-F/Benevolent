from brownie import (
    BenevolentMoonFactory,
    DailyRocket,
    MoonSquares,
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

network.priority_fee("1 gwei")
network.max_fee("50 gwei")

fDaix = convert.to_address("0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09")
host = convert.to_address("0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3")
ida = convert.to_address("0x556ba0b3296027Dd7BCEb603aE53dEc3Ac283d2b")
cfa = convert.to_address("0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F")
#swapRouter =convert.to_address("0xE592427A0AEce92De3Edee1F18E0157C05861564")
DAI = convert.to_address("0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD")
money_handler = convert.to_address("0x6840f713D8fD15DaAB50bCc456F40e9355CE6519")

btc_aggregator = convert.to_address("0x6135b13325bfC4B00278B4abC5e20bbce2D6580e")

account = get_account()

link = interface.LinkTokenInterface("0xa36085F69e2889c224210F603D836748e7dC0088")
dai = interface.IERC20(DAI)
def deploy_fatory():
    factory_contract = (
        BenevolentMoonFactory.deploy({"from": account}, publish_source=True)
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

def deploy_Daily_contracts(asset, salt):
    bytecode1 = DailyRocket[-1].getBytecode(
        1,
        convert.to_string(asset),
        btc_aggregator,
        money_handler
        
    )
    tx = BenevolentMoonFactory[-1].deployDailyRoket(
        bytecode1,
        salt,
        asset,
        {"from": account}
    )
    tx.wait(1)

def deploy_Moon_contract(asset, salt):
    bytecode = MoonSquares[-1].getBytecode(
        2,
        convert.to_string(asset),
        btc_aggregator,
        money_handler
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
        "10 ether",
        {"from": account}
    )

    print(drBTC.getTime())

def moonsquares():
    address = BenevolentMoonFactory[-1].getMSAddress("BTC")
    msBTC = MoonSquares.at(address)

    link.transfer(
        msBTC.address,
        "10 ether",
        {"from": account}
    )

    print(msBTC.getTime())

def daily_transactions(index):

    address = DailyRocket[-1].getDRAddress("BTC")
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

    address = DailyRocket[-1].getMSAddress("BTC")
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
    deploy_Daily_contracts("BTC", 132)
    deploy_Moon_contract("BTC", 256)
    daily_rokecket()
    moonsquares()
    send_transactions()
    
    
    


if __name__ =='__main__':
    main()