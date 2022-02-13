# Benevolent -  
## How to start the project?

Navigate to your prefered directory, then run these commands in your terminal.

**1. Clone the project**
```
git clone https://github.com/Benevolent-MoonG-F/Benevolent.git
```
**2. Navigate to the project directory:**
```
cd Benevolent
```
**3. Install eth-brownie:**
```
pip3 install eth-brownie or pipx install eth-brownie
```  
**4. install openzepelin, chainlink and superfluid packages:**
```
brownie pm intsall <package>
```
**5. set your private key in the brownie-config.yaml**
```
export PRIVATE_KEY="0xhdgfyugwOFGF..."
```
```
brownie run scripts/deploy_for_test.py --network <network>
```
```
dai kovan address: 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD
```
```
daix kovan address: 0x43F54B13A0b17F67E61C9f0e41C3348B3a2BDa09
```


[![built-with openzeppelin](https://img.shields.io/badge/built%20with-OpenZeppelin-3677FF)](https://docs.openzeppelin.com/)




