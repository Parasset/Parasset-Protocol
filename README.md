# Parasset
Use decentralized on-chain native assets, such as ETH and NToken, to generate parallel assets.

![](https://img.shields.io/github/issues/Parasset/Parasset-Protocol)
![](https://img.shields.io/github/stars/Parasset/Parasset-Protocol)
![](https://img.shields.io/github/license/Parasset/Parasset-Protocol)
![](https://img.shields.io/twitter/url?url=https%3A%2F%2Fgithub.com%2FParasset%2FParasset-Protocol%2F)

![image](https://github.com/Parasset/Doc/blob/main/Parasset_Smart_Contracts2.png)

## Documents

**[Parasset V1.0 White Paper](https://github.com/Parasset/Parasset-Doc/blob/main/WhitePaper.pdf)**

**[Parasset V1.0 Contract Specification](https://github.com/Parasset/Parasset-Doc/blob/main/ParassetDocument.pdf)**

**[Parasset V1.0 Contract Structure Diagram](https://github.com/Parasset/Parasset-Doc/blob/main/Parasset_Smart_Contracts2.png)**

**[Audit Report](https://github.com/Parasset/Parasset-Doc/blob/main/Certik_Parasset_final.pdf)**


## Install

```
1. npm init
2. npm install --save-dev hardhat
3. npx hardhat
```


## Compile

```
npx hardhat compile
```

## Run

### Mainnet

```
npx hardhat run scripts/1_1_deployAndSetting_mainnet.js --network mainnet

```
#### V1.0

Contract | Address | Description
---|---|---
NestContract | 0x04abEdA201850aC0124161F037Efd70c74ddC74C | NEST Token
USDTContract | 0xdac17f958d2ee523a2206206994597c13d831ec7 | USDT Token
PTokenFactory | 0xbe612b724B77038bC40A4E4A88335A93A9aA445B | P Asset Factory Contract
MortgagePool | 0xd8E5EfE8DDbe78C8B08bdd70A6dc668F54a6C01c | Mortgage pool contract
InsurancePool | 0xc80Ebc9eC1BB8DBC8e93D4C904372dD19786dc9C | Insurance pool contract
PriceController | 0xd0a9FBFFB1EBa24Ae4A0C11B13FA9B26BF019548 | Price call contract
NTokenController | 0xc4f1690eCe0145ed544f0aee0E2Fa886DFD66B62 | NTokenController
NestQuery | 0xB5D2890c061c321A5B6A4a4254bb1522425BAF0A | NEST Oracle
PUSDT | 0xCCEcC702Ec67309Bc3DDAF6a42E9e5a6b8Da58f0 | PUSDT
PETH | 0x53f878Fb7Ec7B86e4F9a0CB1E9a6c89C0555FbbD | PETH


Parameter | Value
---|---
Market base interest rate | 0.02
Nest mortgage rate ceiling | 40%
ETH Mortgage rate ceiling | 70%
Nest liquidation mortgage rate | 75%
ETH liquidation mortgage rate | 84%
Insurance redemption cycle | 2 days
Waiting time for redemption | 14 days
Initial net value | 1
Exchange rate | 2‰

#### 20210430

Contract | Address | Description
---|---|---
NestContract | 0x04abEdA201850aC0124161F037Efd70c74ddC74C | NEST Token
USDTContract | 0xdac17f958d2ee523a2206206994597c13d831ec7 | USDT Token
PTokenFactory | 0x978f0038A69a0ecA925df4510e0085747744dDA8 | P Asset Factory Contract
MortgagePool | 0xd49bFB7e44E3E66a59b934D45CcBf9165AcE34b3 | Mortgage pool contract
InsurancePool | 0x46955ccEc435465C8C70BD64E2f5FFBd33308C8C | Insurance pool contract
PriceController | 0x2Ce14C65cD3cCC546433E3b1E8c712E102377635 | Price call contract
NTokenController | 0xc4f1690eCe0145ed544f0aee0E2Fa886DFD66B62 | NTokenController
NestQuery | 0xB5D2890c061c321A5B6A4a4254bb1522425BAF0A | NEST Oracle
PUSDT | 0x9786bD44c30cD84Fc6C9b026c2e826De066F688c | PUSDT
PETH | 0x6319F81e8C5F5E20fD675bc484EdFbb7E121831a | PETH

### Ropsten

```
npx hardhat run scripts/1_deployAndSetting.js --network ropsten

```

#### V1.9

Fix problems in contract audit

price:

2USDT=1ETH

3NEST=1ETH

Insurance redemption time: redeem once every 30 minutes, each redemption time is 15 minutes.

Contract | Address | Description
---|---|---
NestContract | 0xd791228a2eeb931739A5faC4a41af55fA194E08E | NEST Token
USDTContract | 0x955702776C7624f3EF4B49d6900946ED4f403d9A | USDT Token
PTokenFactory | 0xe635F9d3e3EFE67Ad42898F38d2E373270CD58c3 | P Asset Factory Contract
MortgagePool | 0x3048bC3cd8dbCE68c7b4E6D5E0c117bD2885322D | Mortgage pool contract
InsurancePool | 0xe0bc8c4f65f08ab71437bdA1f261d9E6A96A6F66 | Insurance pool contract
PriceController | 0x32ED66917687131f3852Fc64A638b8e8D9f3b5aa | Price call contract
NestQuery | 0xbF6dBeF11649fa1b55f850fd003ff4c3B4E5C025 | NEST Oracle
PUSDT | 0xffaa58c0bc5069E19FcCa94aDb70EA63578F9860 | PUSDT
PETH | 0x64B100bDA18c2A5AF4A370547adaB2712Dcf41dD | PETH

### Rinkeby

#### V1.2

parameter settings:

Nest mortgage rate upper limit is 40%, nest liquidation line: 75%

The upper limit of the ETH mortgage rate is 70%, and the ETH liquidation line: 84%

price:

2USDT=1ETH

3NEST=1ETH

Insurance redemption time: redeem once every 30 minutes, each redemption time is 15 minutes

Contract | Address | Description
---|---|---
NestContract | 0x52805f9C36E7F9eC6390DCB51f7fB8Cc1575A85e | NEST Token
USDTContract | 0xC4FC237b2BB407d14ce925F70063Ef7312A336B6 | USDT Token
PTokenFactory | 0x5C6aa34708a1c7F9D40aF15C9FAD54B6aFaaEc8D | P Asset Factory Contract
MortgagePool | 0x509F84D973B2C75fD62a8454d80575fF89FDe3d4 | Mortgage pool contract
InsurancePool | 0xf4B0b23Fe4C0F21c627a7f94E6F2A0d08694B8Db | Insurance pool contract
PriceController | 0xAcc44E0F32766174B3BE4Fc1735EeCAe9E74287B | Price call contract
NTokenController | 0xeA77d90E3B54CbF6ED1053Ec60680Fa223deb4cf | NTokenController
NestQuery | 0x11Cf802193Ae6167622b0c68007882A0D90B7642 | NEST Oracle
PUSDT | 0xBf1710D43C3BdC50195c15019F48DC5c1f065806 | PUSDT
PETH | 0x039D3f87F90Ec6F1fc73467c396093418ece53aC | PETH

### .private.json

>Rename sample.private.json to .private.json

```
{
    //  node private key
    "alchemy": {
        "ropsten": {
            "apiKey": "XXX"
        },
        "mainnet": {
            "apiKey": "XXX"
        }
    },
    //  private key
    "account": {
        "ropsten": {
            "key": "XXX",
            "userA": "XXX",
            "userB": "XXX"
        },
        "mainnet": {
            "key": "XXX",
            "userA": "XXX",
            "userB": "XXX"
        }
    }
}
```





