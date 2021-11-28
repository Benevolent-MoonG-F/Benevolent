from brownie import RedirectAll, accounts, network, config
from scripts.helpful_scripts import get_account



def main():
    account = get_account()
    RedirectAll.deploy(
        0xEB796bdb90fFA0f28255275e16936D25d3418603,#host
        0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873,#cfa
        0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f,#fDaix
        0x823ff565c67509fc986bFbC45BE7dE4Ecafb3841,#Token
        0xA843fF69D74c3BC2504a112F9739CDf393B2b4d7, #moonSquares
        {'from': account})
    
if __name__ == '__main__':
    main()