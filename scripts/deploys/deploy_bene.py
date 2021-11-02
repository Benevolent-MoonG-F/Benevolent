from brownie import GG, accounts, network, config

def main():
    account = accounts.add(config['wallets']['from_key']) or accounts[0]
    GG.deploy({'from': account})
    
if __name__ == '__main__':
    main()