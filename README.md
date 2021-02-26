![image](https://github.com/Parasset/Doc/blob/main/Parasset_Smart_Contracts.png)

## 安装

```
1. npm init
2. npm install --save-dev hardhat
3. npx hardhat
```


## 编译合约

```
npx hardhat compile
```

## 运行

### 本地环境

```
// 抵押ETH铸PUSDT
npx hardhat run scripts/ETHUSDTtest.js
// 抵押NEST铸PUSDT
npx hardhat run scripts/NESTUSDTtest.js
```

### Ropsten

```
npx hardhat run scripts/deployAndSetting_ropsten.js --network ropsten

```

合约 | 地址 | 描述
---|---
NestContract | 0x1e481DA2B644d2E63b0aa36e3D6eFb8a802804CF | NEST Token合约
USDTContract | 0xfA3b8a37e941b8b3e83F0505A104a91330bd40Ba | USDT Token 合约
PTokenFactory | 0x260D92a64D24eCCE01db2013E060Af99aE95A4F0 | P资产工厂合约
MortgagePool | 0x99a57B75b968e73eec8D46eDCde5EC2998101f52 | 抵押池合约
InsurancePool | 0xc52027340De12037FC2A6865DdcD693011D3d8fe | 保险池合约
NestQuery | 0xAE0A2Da0139E27b352aB44A68ABcEcBAD9c9a483 | NEST 价格合约
PUSDT | 0xB5f515c6E6cbed73E21f3d1278b3265511a5d2fb | PUSDT合约
PETH | 0xFA189E7774325D172A0580C4523E98972c20c7e3 | PETH合约

### .private.json

>将sample.private.json更名为.private.json

```
{
    //  infura节点私钥
    "alchemy": {
        "ropsten": {
            "apiKey": "XXX"
        },
        "mainnet": {
            "apiKey": "XXX"
        }
    },
    //  填写私钥
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



