from brownie import RedirectAll, accounts, network, config

def main():
    account = accounts.add(config['wallets']['from_key']) or accounts[0]
    RedirectAll.deploy(
        0xEB796bdb90fFA0f28255275e16936D25d3418603,
        0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873,
        0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f,
        0x823ff565c67509fc986bFbC45BE7dE4Ecafb3841,
        {'from': account})
    
if __name__ == '__main__':
    main()