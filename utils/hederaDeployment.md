# Hedera Deployment Solution: BalanceMismatch Fix

## Problem Summary
The Carbon protocol fails on Hedera with `BalanceMismatch()` errors because:
- Hedera HTS tokens incur network fees during transfers
- Carbon's validation expects exact balance changes: `newBalance - prevBalance == depositAmount`
- Network fees cause `newBalance - prevBalance < depositAmount`

## Solution: HederaTokenWrapper Contract

### Why This Works
1. **User** → sends compensated amount to **Wrapper**
2. **Wrapper** → transfers exact expected amount to **Carbon**
3. **Wrapper** → retains fee buffer to handle Hedera network fees

### Deployment Steps

1. **Deploy HederaTokenWrapper**
   ```bash
   # Deploy the wrapper with Carbon controller address
   npx hardhat run scripts/deploy-hedera-wrapper.js --network hederaTestnet
   ```

2. **Update Frontend Integration**
   ```typescript
   // Instead of calling Carbon directly:
   // carbonController.createStrategy(token0, token1, orders)
   
   // Use the wrapper:
   hederaTokenWrapper.createStrategy(token0, token1, orders)
   ```

3. **Frontend Fee Calculation**
   ```typescript
   import { prepareHederaTransaction } from './utils/hederaFeeCalculator';
   
   const { compensatedAmount, gasLimit } = prepareHederaTransaction(
     originalAmount, 
     chainId
   );
   
   // Approve compensated amount to wrapper
   await token.approve(wrapperAddress, compensatedAmount);
   ```

### Benefits
- ✅ No core protocol changes
- ✅ No re-auditing required  
- ✅ Handles fee variations automatically
- ✅ Backward compatible
- ✅ Easy to upgrade

### Gas Recommendations for Hedera
- **Standard networks**: 200,000 gas limit
- **Hedera networks**: 800,000 gas limit (for HTS operations)

### Fee Estimation
- **Conservative approach**: 0.01% of transfer amount
- **Minimum buffer**: 1 unit for small amounts
- **Adjustable**: Can be updated based on real network conditions

## Alternative: Direct Integration (Advanced)

For teams wanting tighter integration, you can:

1. **Calculate exact fees** using Hedera SDK
2. **Pre-fund strategies** with exact post-fee amounts
3. **Monitor network conditions** for dynamic adjustment

However, the wrapper approach is recommended for:
- Simplicity
- Reliability  
- Maintainability 