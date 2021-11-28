from brownie import BMSGToken, accounts, network, config
from scripts.helpful_scripts import get_account

fDaix = 0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f
host = 0xEB796bdb90fFA0f28255275e16936D25d3418603
ida = 0x804348D4960a61f2d5F9ce9103027A3E849E09b8
cfa = 0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873

def main():
    account = get_account()
    governance_token = (
        BMSGToken.deploy(
            fDaix,
            host,                ida,
            {"from": account},
            publish_source=config["networks"][network.show_active()].get(
                "verify", False
            ),
        )
        if len(BMSGToken) <= 0
        else BMSGToken[-1]
    )
    governance_token.delegate(account, {"from": account})
    
if __name__ == '__main__':
    main()