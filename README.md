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



