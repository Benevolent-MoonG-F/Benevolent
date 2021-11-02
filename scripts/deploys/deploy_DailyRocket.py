from brownie import DailyRocket, accounts, network, config

def main():
    account = accounts.add(config['wallets']['from_key']) or accounts[0]
    DailyRocket.deploy(0xFvkgdvhgdvgdv, 0xShgdchgdsgvsdjh, {'from': account})
    #the constructor has two arguments, addresses of allowed ERC20 tokens
if __name__ == '__main__':
    main()