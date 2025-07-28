import { CarbonBatcher, ProxyAdmin } from '../../../components/Contracts';
import { DeployedContracts, describeDeployment } from '../../../utils/Deploy';
import { expect } from 'chai';
import { ethers } from 'hardhat';

describeDeployment(__filename, () => {
    let proxyAdmin: ProxyAdmin;
    let carbonBatcher: CarbonBatcher;

    beforeEach(async () => {
        proxyAdmin = await DeployedContracts.ProxyAdmin.deployed();
        carbonBatcher = await DeployedContracts.CarbonBatcher.deployed();
    });

    it('should deploy and configure the carbon batcher contract', async () => {
        expect(await proxyAdmin.getProxyAdmin(carbonBatcher.address)).to.equal(proxyAdmin.address);
        expect(await carbonBatcher.version()).to.equal(1);
    });

    it('carbon batcher implementation should be initialized', async () => {
        const implementationAddress = await proxyAdmin.getProxyImplementation(carbonBatcher.address);
        const carbonBatcherImpl: CarbonBatcher = await ethers.getContractAt('CarbonBatcher', implementationAddress);
        // hardcoding gas limit to avoid gas estimation attempts (which get rejected instead of reverted)
        const tx = await carbonBatcherImpl.initialize({ gasLimit: 6000000 });
        await expect(tx.wait()).to.be.reverted;
    });

    it('cannot call postUpgrade on carbon batcher', async () => {
        // hardcoding gas limit to avoid gas estimation attempts (which get rejected instead of reverted)
        const tx = await carbonBatcher.postUpgrade(true, '0x', { gasLimit: 6000000 });
        await expect(tx.wait()).to.be.reverted;
    });
});
