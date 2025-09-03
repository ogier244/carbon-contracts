# Carbon for Hedera Network

## Setup

As a first step of contributing to the repo, you should install all the required dependencies via:

```sh
pnpm install
```

You will also need to create and update the `.env` file if you’d like to deploy contracts to Hedera Testnet (see [.env.example](./.env.example))

Fill your deloy wallet private key for variable `HEDERA_DEPLOY_PRIVATE_KEY` before running deploy script. Remember faucet some HBAR testnet for wallet here: https://portal.hedera.com/faucet

#### Install forge for testing
```sh
# Install foundryup
curl -L https://foundry.paradigm.xyz | bash

# Install nightly dependencies
foundryup --install nightly-56dbd20c7179570c53b6c17ff34daa7273a4ddae
foundryup --use nightly-56dbd20c7179570c53b6c17ff34daa7273a4ddae
```

## Testing

Testing the protocol is possible via multiple approaches:

### Unit Tests

You can run the full test suite via:

Forge unit test
```sh
pnpm test
```

Hardhat test
```sh
pnpm test:hardhat
```

#### Instructions

In order to audit the test coverage of the full test suite, run:

```sh
pnpm test:coverage
```

## Deployments

You can deploy the fully configured Carbon protocol on any network by setting up the `HARDHAT_NETWORK` environmental variable in .env and running:

```sh
pnpm deploy:prepare && pnpm deploy:network
```

If you’d like to deploy contracts to other network, run like following:
```sh
pnpm deploy:prepare && HARDHAT_NETWORK=<network> pnpm deploy:network
```

The deployment artifacts are going to be in `deployments/hedera-testnet`. The deployed contract address is in file `deployments/hedera-testnet/<Contract_Name>.json>`

You can make changes to the deployment scripts by modifying them in `deploy/scripts/network` and you can add specific network data in `data/named-accounts.ts` (Relevant to Carbon Vortex)  
