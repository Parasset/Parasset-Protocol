![image](https://github.com/Parasset/Doc/blob/main/Parasset_Smart_Contracts2.png)

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
#### V1.0

合约 | 地址 | 描述
---|---|---
NestContract | 0x1e481DA2B644d2E63b0aa36e3D6eFb8a802804CF | NEST Token合约
USDTContract | 0xfA3b8a37e941b8b3e83F0505A104a91330bd40Ba | USDT Token 合约
PTokenFactory | 0x260D92a64D24eCCE01db2013E060Af99aE95A4F0 | P资产工厂合约
MortgagePool | 0x99a57B75b968e73eec8D46eDCde5EC2998101f52 | 抵押池合约
InsurancePool | 0xc52027340De12037FC2A6865DdcD693011D3d8fe | 保险池合约
NestQuery | 0xa5993c159947390f0858A2dD1a887590AF1E20da | NEST 价格合约
PUSDT | 0xB5f515c6E6cbed73E21f3d1278b3265511a5d2fb | PUSDT合约
PETH | 0xFA189E7774325D172A0580C4523E98972c20c7e3 | PETH合约

#### V1.1

增加查询其他人债仓数据接口

合约 | 地址 | 描述
---|---|---
MortgagePool | 0x3A94F468ADC13F1715c094388417C599810f3ed9 | 抵押池合约
InsurancePool | 0x37b9F494ee29C9907684415681247FE3ec150ff0 | 保险池合约

#### V1.2

1. 增加价格调用合约
2. 修改抵押率展示方式
3. 增加P资产增发、销毁日志

价格：

2USDT=1ETH

3NEST=1ETH

合约 | 地址 | 描述
---|---|---
NestContract | 0xae6E04ED92FC12238852cA212f09b96Dc23407C1 | NEST Token合约
USDTContract | 0xEDfe846E914d0aaaA42aC031D2D5Fc5467E68a81 | USDT Token 合约
PTokenFactory | 0x94914baE774EcAc54a29078F010ef7c588573f4d | P资产工厂合约
MortgagePool | 0xBFDFD8b3a95A4863ae00772d81A9d5Ff1894AF5E | 抵押池合约
InsurancePool | 0x610a0e22286C6408A2384D7Ff14a10B85C6d8E50 | 保险池合约
PriceController | 0xEBb7eEbC4DF86Ae5917FAD26A2B3464BB97e0C95 | 价格调用合约
NestQuery | 0x364b22983ed7EABb4de94924D7e17411FDE674Ae | NEST 价格合约
PUSDT | 0x1a8A52074932Af7333626a3e757524E3667D78C5 | PUSDT合约
PETH | 0x282f780533B748a256872E5855d3d84C3bf64Ac0 | PETH合约

#### V1.3

1. 增加抵押资产、减少铸币，抵押率不能低于0%
2. 铸币、减少抵押、新增铸币，抵押率小于等于70%
3. 增加返回地址列表，单条数据查询接口

价格：

2USDT=1ETH

3NEST=1ETH

保险赎回时间：10分钟赎回一次，每次赎回时间5分钟

合约 | 地址 | 描述
---|---|---
NestContract | 0xae6E04ED92FC12238852cA212f09b96Dc23407C1 | NEST Token合约
USDTContract | 0xEDfe846E914d0aaaA42aC031D2D5Fc5467E68a81 | USDT Token 合约
PTokenFactory | 0x94914baE774EcAc54a29078F010ef7c588573f4d | P资产工厂合约
MortgagePool | 0x73fc3699F2aD42Cb3ae8dB0F998B36E9BB784324 | 抵押池合约
InsurancePool | 0xf8246405404c59964206Fac834317f2f50b9a670 | 保险池合约
PriceController | 0xEBb7eEbC4DF86Ae5917FAD26A2B3464BB97e0C95 | 价格调用合约
NestQuery | 0x364b22983ed7EABb4de94924D7e17411FDE674Ae | NEST 价格合约
PUSDT | 0x1a8A52074932Af7333626a3e757524E3667D78C5 | PUSDT合约
PETH | 0x282f780533B748a256872E5855d3d84C3bf64Ac0 | PETH合约

#### V1.4

1. 增加保险返回上期赎回时间接口
2. 增加抵押池操作，手续费日志

价格：

2USDT=1ETH

3NEST=1ETH

保险赎回时间：10分钟赎回一次，每次赎回时间5分钟

合约 | 地址 | 描述
---|---|---
NestContract | 0xae6E04ED92FC12238852cA212f09b96Dc23407C1 | NEST Token合约
USDTContract | 0xEDfe846E914d0aaaA42aC031D2D5Fc5467E68a81 | USDT Token 合约
PTokenFactory | 0x94914baE774EcAc54a29078F010ef7c588573f4d | P资产工厂合约
MortgagePool | 0x16bCC9A1206A3cD3c4A11aBED4A73bae20aFA1aa | 抵押池合约
InsurancePool | 0xf1dfE5c3C0D2D26a721514f31BE02D90EE54D5B3 | 保险池合约
PriceController | 0xEBb7eEbC4DF86Ae5917FAD26A2B3464BB97e0C95 | 价格调用合约
NestQuery | 0x364b22983ed7EABb4de94924D7e17411FDE674Ae | NEST 价格合约
PUSDT | 0x1a8A52074932Af7333626a3e757524E3667D78C5 | PUSDT合约
PETH | 0x282f780533B748a256872E5855d3d84C3bf64Ac0 | PETH合约

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





