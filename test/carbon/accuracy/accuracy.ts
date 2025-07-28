import Contracts, { TestStrategies } from '../../../components/Contracts';
import { encodeOrder } from '../../utility/carbon-sdk';
import { expect } from 'chai';
import Decimal from 'decimal.js';
import { BigNumber } from 'ethers';

// created via https://github.com/bancorprotocol/carbon-simulator/blob/main/benchmark/test_trade.py
// located at https://github.com/bancorprotocol/carbon-simulator/tree/main/benchmark/resources/trade
import ArbitraryTrade from './data/ArbitraryTrade.json';
import EthUsdcTrade from './data/EthUsdcTrade.json';
import ExtremeSrcTrade from './data/ExtremeSrcTrade.json';
import ExtremeTrgTrade from './data/ExtremeTrgTrade.json';

const tests = [...ArbitraryTrade, ...EthUsdcTrade, ...ExtremeSrcTrade, ...ExtremeTrgTrade];

describe('Accuracy stress test', () => {
    let contract: TestStrategies;

    before(async () => {
        contract = await Contracts.TestStrategies.deploy();
    });

    for (let mantissaLength = 0; mantissaLength <= 48; mantissaLength++) {
        for (let exponent = 0; exponent < 64; exponent++) {
            const mantissa = BigNumber.from(1).shl(mantissaLength).sub(1);
            const rate = BigNumber.from(exponent).shl(48).or(mantissa);
            const rateShouldBeValid = rate.lt(BigNumber.from(49).shl(48));
            it(`rate ${rate} should be ${rateShouldBeValid ? '' : 'in'}valid`, async () => {
                expect(await contract.isValidRate(rate)).to.eq(rateShouldBeValid);
                if (rateShouldBeValid) {
                    const expandedRate = await contract.expandedRate(rate);
                    expect(expandedRate).to.be.lt(BigNumber.from(1).shl(96));
                    expect(expandedRate).to.be.eq(mantissa.shl(exponent));
                }
            });
        }
    }

    for (const [index, test] of tests.entries()) {
        it(`test ${index + 1} out of ${tests.length}`, async () => {
            const order = encodeOrder({
                liquidity: new Decimal(test.order.liquidity),
                lowestRate: new Decimal(test.order.lowestRate),
                highestRate: new Decimal(test.order.highestRate),
                marginalRate: new Decimal(test.order.marginalRate)
            });
            const amount = BigNumber.from(test.amount);
            const tradeRPC = (contract as any)[test.method](order, amount);
            const expected = BigNumber.from(test.output.impl);
            expect(await tradeRPC).to.eq(expected);
        });
    }
});
