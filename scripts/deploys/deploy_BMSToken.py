from brownie import BMSToken, accounts, network, config

def main():
    account = accounts.add(config['wallets']['from_key']) or accounts[0]
    BMSToken.deploy(
        0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f,#Daix
        0xEB796bdb90fFA0f28255275e16936D25d3418603,#host
        0x804348D4960a61f2d5F9ce9103027A3E849E09b8, #ida
        {'from': account}
    )
    
if __name__ == '__main__':
    main()