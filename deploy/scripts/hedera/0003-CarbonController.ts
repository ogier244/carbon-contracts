import { ZERO_ADDRESS } from '../../../utils/Constants';
import {
    DeployedContracts,
    deployProxy,
    execute,
    grantRole,
    InstanceName,
    setDeploymentMetadata,
    upgradeProxy
} from '../../../utils/Deploy';
import { Roles } from '../../../utils/Roles';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const func: DeployFunction = async ({ getNamedAccounts, ethers }: HardhatRuntimeEnvironment) => {
    const { deployer } = await getNamedAccounts();
    const voucher = await DeployedContracts.Voucher.deployed();

    await deployProxy({
        name: InstanceName.CarbonController,
        from: deployer,
        args: [voucher.address, ZERO_ADDRESS]
    });

    // immediate upgrade is required to set the proxy address in OnlyProxyDelegate
    const carbonController = await DeployedContracts.CarbonController.deployed();
    await upgradeProxy({
        name: InstanceName.CarbonController,
        from: deployer,
        args: [voucher.address, carbonController.address],
        checkVersion: false
    });

    // Set the carbon controller address in the voucher contract
    await execute({
        name: InstanceName.Voucher,
        methodName: 'setController',
        args: [carbonController.address],
        from: deployer
    });

    // CRITICAL: Grant ROLE_MINTER to the controller so it can mint strategy NFTs
    // Use direct contract interaction with manual gas limit to avoid estimation issues
    try {
        // Get contract instance
        const voucherContract = await ethers.getContract(InstanceName.Voucher);
        
        // Call grantRole with a manual gas limit
        const tx = await voucherContract.grantRole(
            Roles.Voucher.ROLE_MINTER,
            carbonController.address,
            { from: deployer, gasLimit: 300000 }
        );
        
        console.log(`Granting ROLE_MINTER to controller (tx: ${tx.hash})...`);
        await tx.wait();
        console.log("✅ ROLE_MINTER granted to controller successfully");
    } catch (error: any) {
        console.error("❌ Failed to grant ROLE_MINTER to controller:", error.message || String(error));
        console.log("Continuing with deployment, but strategy creation may fail");
    }

    return true;
};

export default setDeploymentMetadata(__filename, func);
