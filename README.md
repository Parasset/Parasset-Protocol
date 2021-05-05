# Parasset
Use decentralized on-chain native assets, such as ETH and NToken, to generate parallel assets.

![](https://img.shields.io/github/issues/Parasset/Parasset-Protocol)
![](https://img.shields.io/github/stars/Parasset/Parasset-Protocol)
![](https://img.shields.io/github/license/Parasset/Parasset-Protocol)
![](https://img.shields.io/twitter/url?url=https%3A%2F%2Fgithub.com%2FParasset%2FParasset-Protocol%2F)

![image](https://github.com/Parasset/Doc/blob/main/Parasset_Smart_Contracts2.png)

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





