import { DeployedContracts, deployProxy, InstanceName, setDeploymentMetadata } from '../../../utils/Deploy';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const func: DeployFunction = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
    const { deployer } = await getNamedAccounts();

    const voucher = await DeployedContracts.Voucher.deployed();

    await deployProxy({
        name: InstanceName.CarbonBatcher,
        from: deployer,
        args: [voucher.address]
    });

    return true;
};

export default setDeploymentMetadata(__filename, func);
