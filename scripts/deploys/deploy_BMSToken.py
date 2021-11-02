from brownie import BMSToken, accounts, network, config

def main():
    account = accounts.add(config['wallets']['from_key']) or accounts[0]
    BMSToken.deploy({'from': account})
    
if __name__ == '__main__':
    main()