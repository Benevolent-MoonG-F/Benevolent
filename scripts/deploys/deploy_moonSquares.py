from brownie import MoonSquares, accounts, network, config

def main():
    account = accounts.add(config['wallets']['from_key']) or accounts[0]
    MoonSquares.deploy({'from': account}) #should include all constructor parameters
    
if __name__ == '__main__':
    main()