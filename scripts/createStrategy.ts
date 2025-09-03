import Contracts from '../components/Contracts';
import { DeployedContracts, getNamedSigners } from '../utils/Deploy';
import Logger from '../utils/Logger';
import '@nomiclabs/hardhat-ethers';
import '@typechain/hardhat';
import { ethers } from 'hardhat';

const TOKENS = [
    {
        address: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
        symbol: 'HBAR'
    },
    {
        address: '0x0000000000000000000000000000000000068cda',
        symbol: 'USDC'
    }
];

const order1 = { y: "1000000", z: "2162491", A: "2825066944866", B: "26837586010238" };
const order2 = { y: "110324966", z: "215218921", A: "281090611912736", B: "1292794037607971" };

const main = async () => {
    const { deployer } = await getNamedSigners();
    const carbonController = await DeployedContracts.CarbonController.deployed();


    // This is a approve USDC token for a Carbon Controller Contract
    const usdcToken = await Contracts.ERC20.attach(TOKENS[1].address);

    // Check approve status
    const approveStatus = await usdcToken.callStatic.approve(carbonController.address, ethers.utils.parseEther("5"));

    // Approve
    await usdcToken.approve(carbonController.address, ethers.utils.parseEther("5"));
    console.log("Approved USDC to Carbon Controller successfully", approveStatus);

    // Check createStrategy
    // The decimal precision of HBAR varies across the different Hedera APIs. 
    // While HAPI, JSON-RPC Relay, and Hedera Smart Contract Service (EVM) provide 8 decimal places, the msg.value in JSON-RPC Relay provides 18 decimal places.
    // https://docs.hedera.com/hedera/sdks-and-apis/sdks/hbars#hbar-decimal-places
    const id = await carbonController.callStatic.createStrategy(TOKENS[1].address, TOKENS[0].address, [order1, order2], { value: "1103249662476401554" });
    await carbonController.createStrategy(TOKENS[1].address, TOKENS[0].address, [order1, order2], { value: "1103249662476401554" });
    console.log('Created new strategy with pair of token HBAR-USDC | Strategy ID:', id);

    // Get Pair Information
    const pair = await carbonController.pair(TOKENS[1].address, TOKENS[0].address);
    console.log("Pair information:", pair.id, pair.tokens[0], pair.tokens[1]);
    console.log(await carbonController.strategiesByPair(TOKENS[1].address, TOKENS[0].address, 0, 10));

    // Using HBAR Buy USDC
    await carbonController.callStatic.tradeByTargetAmount(TOKENS[0].address, TOKENS[1].address,
        [],
        Math.floor((Date.now()) / 1000 + 500), '100000000',
        { value: ethers.utils.parseUnits("1", 18) });
    console.log("Trade executed successfully");
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        Logger.error(error);
        process.exit(1);
    });