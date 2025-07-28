# Deploying Carbon Protocol to Hedera Testnet

This document outlines the process and changes required to deploy the Carbon protocol to Hedera Testnet.

## Prerequisites

- Node.js and npm installed
- Private key for a funded Hedera Testnet account
- Access to a Hedera Testnet RPC endpoint

## Configuration Changes

### 1. Network Configuration

#### Chain ID Configuration
Add Hedera Testnet to `utils/chainIds.json`:

```json
{
    "mainnet": 1,
    // ... other networks ...
    "hedera": 295,
    "hederaTestnet": 296,
    // ... other networks ...
}
```

#### RPC URL Configuration
Add Hedera Testnet RPC URL to `utils/rpcUrls.json`:

```json
{
    "mainnet": "https://mainnet.infura.io/v3/your-api-key",
    // ... other networks ...
    "hederaTestnet": "https://testnet.hashio.io/api",
    // ... other networks ...
}
```

### 2. Hardhat Configuration

Update `hardhat.config.ts` to include Hedera Testnet:

```typescript
[DeploymentNetwork.HederaTestnet]: {
    chainId: chainIds[DeploymentNetwork.HederaTestnet],
    url: rpcUrls[DeploymentNetwork.HederaTestnet],
    accounts: process.env.HEDERA_TESTNET_PRIVATE_KEY ? [`0x${process.env.HEDERA_TESTNET_PRIVATE_KEY}`] : [],
    gasPrice,
    saveDeployments: true,
    live: true,
    deploy: [`deploy/scripts/${DeploymentNetwork.HederaTestnet}`]
    // Verification for HashScan might need a custom setup or plugin
}
```

### 3. Contract Size Optimization

Modify optimizer settings in `hardhat.config.ts` to reduce contract size to meet Hedera's limit of 24,576 bytes:

```typescript
solidity: {
    compilers: [
        {
            version: '0.8.19',
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200  // Changed from 2000 to reduce contract size
                },
                metadata: {
                    bytecodeHash: 'none'
                },
                outputSelection: {
                    '*': {
                        '*': ['storageLayout']
                    }
                }
            }
        }
    ]
}
```

### 4. Named Accounts Configuration

Add Hedera Testnet entries to `data/named-accounts.ts`:

```typescript
const VortexNamedAccounts = {
    targetToken: {
        ...getAddress(mainnet, NATIVE_TOKEN_ADDRESS),
        [DeploymentNetwork.HederaTestnet]: NATIVE_TOKEN_ADDRESS
    },
    finalTargetToken: {
        ...getAddress(mainnet, '0x1F573D6Fb3F13d689FF844B4cE37794d79a7FF1C'),
        [DeploymentNetwork.HederaTestnet]: ZERO_ADDRESS
    },
    transferAddress: {
        ...getAddress(mainnet, '0x1F573D6Fb3F13d689FF844B4cE37794d79a7FF1C'),
        [DeploymentNetwork.HederaTestnet]: '0x5bEBA4D3533a963Dedb270a95ae5f7752fA0Fe22'  // Not needed with our script modification
    }
};
```

## Deployment Scripts

### 1. Create Initial Config Script

Create file `deploy/scripts/hederaTestnet/0000-Config.ts`:

```typescript
import { getNetworkNameById } from '../../../utils/Deploy';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import Logger from '../../../utils/Logger';

// This is a configuration script that runs before any deployment to ensure proper network setup
const func: DeployFunction = async ({ network, getNamedAccounts }: HardhatRuntimeEnvironment) => {
    const networkName = network.name;
    Logger.log(`Deploying to network: ${networkName}`);
    
    // Hedera-specific configuration
    if (networkName === 'hederaTestnet') {
        Logger.log('Configuring for Hedera Testnet...');
        Logger.log('- Native token: HBAR (8 decimals)');
        Logger.log('- Network ID: 296');
        
        // Any Hedera-specific configuration can be done here
        // Note: Actual token.sol modifications need to be done separately
    }

    return true;
};

// Set this to run first
func.id = '0000-Config';
func.tags = ['Config'];
func.runAtTheEnd = false;

export default func;
```

### 2. Modify CarbonVortex Deployment Script

Modify `deploy/scripts/hederaTestnet/0004-CarbonVortex.ts` to use the deployer address directly:

```typescript
const func: DeployFunction = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
    const { deployer, targetToken, finalTargetToken } = await getNamedAccounts();
    const carbonController = await DeployedContracts.CarbonController.deployed();

    await deployProxy(
        {
            name: InstanceName.CarbonVortex,
            from: deployer,
            args: [carbonController.address, ZERO_ADDRESS, targetToken, finalTargetToken]
        },
        {
            args: [deployer]  // Using deployer address directly instead of transferAddress
        }
    );

    const carbonVortex = await DeployedContracts.CarbonVortex.deployed();

    await grantRole({
        name: InstanceName.CarbonController,
        id: Roles.CarbonController.ROLE_FEES_MANAGER,
        member: carbonVortex.address,
        from: deployer
    });

    return true;
};
```

## Environment Setup

Create or update `.env` file with the following content:

```
# Config for multi-network deployment
HARDHAT_NETWORK=hederaTestnet
VERIFY_API_KEY=

# Custom gas price for deployments
GAS_PRICE=auto

# Hedera specific configuration
HEDERA_TESTNET_PRIVATE_KEY=your_private_key_without_0x_prefix
```

## Running the Deployment

1. Copy all other deployment scripts from mainnet or another network to the `deploy/scripts/hederaTestnet` directory.

2. Execute the deployment with:
```bash
npx hardhat deploy --network hederaTestnet
```

## Contract Verification

Hedera contracts can be verified on HashScan. However, HashScan's verification process might differ from Etherscan. At the time of writing, the hardhat-etherscan plugin doesn't support HashScan directly, so manual verification may be required.

## Troubleshooting

### Contract Size Issues

If you encounter contract size errors even after reducing optimizer runs, you may need to:

1. Split large contracts into smaller ones
2. Remove unused functions
3. Further reduce optimizer runs (try 50 or 1)
4. Use libraries for common functions

### RPC Errors

If you encounter RPC errors like HTTP 502 Bad Gateway:

1. The Hedera Testnet RPC endpoint might be temporarily unavailable
2. Try again later or use a different RPC endpoint
3. For specific transactions that failed, they can be manually executed later

## Notes on Hedera Specifics

- HBAR has 8 decimals (unlike ETH's 18 decimals)
- The native token address is represented by `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`
- Contract size limit on Hedera is 24,576 bytes 