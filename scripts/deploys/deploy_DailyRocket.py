from brownie import DailyRocket, accounts, network, config

def main():
    account = accounts.add(config['wallets']['from_key']) or accounts[0]
    DailyRocket.deploy(
        0x8f3cf7ad23cd3cadbd9735aff958023239c6a063,
        {'from': account}
    )
    #the constructor has two arguments, addresses of allowed ERC20 tokens
if __name__ == '__main__':
    main()
