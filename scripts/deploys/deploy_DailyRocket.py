from brownie import DailyRocket, accounts, network, config
from scripts.helpful_scripts import get_account

fDai = 0x15F0Ca26781C3852f8166eD2ebce5D18265cceb7


def main():
    account = get_account()
    DailyRocket.deploy(
        fDai,
        {'from': account}
    )
    #the constructor has two arguments, addresses of allowed ERC20 tokens
if __name__ == '__main__':
    main()
