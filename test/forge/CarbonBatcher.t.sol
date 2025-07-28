// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { TestFixture } from "./TestFixture.t.sol";

import { Order } from "../../contracts/carbon/Strategies.sol";

import { StrategyData } from "../../contracts/utility/CarbonBatcher.sol";

import { AccessDenied, InvalidAddress, ZeroValue, InsufficientNativeTokenSent } from "../../contracts/utility/Utils.sol";

import { Token, NATIVE_TOKEN } from "../../contracts/token/Token.sol";

contract CarbonBatcherTest is TestFixture {
    using Address for address payable;

    /**
     * @dev triggered when a strategy is created
     */
    event StrategyCreated(
        uint256 id,
        address indexed owner,
        Token indexed token0,
        Token indexed token1,
        Order order0,
        Order order1
    );

    /**
     * @dev triggered when strategies have been created
     */
    event StrategiesCreated(address indexed owner, uint256[] strategyIds);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @dev function to set up state before tests
    function setUp() public virtual {
        // Set up tokens and users
        systemFixture();
        // Deploy Carbon Controller and Voucher
        setupCarbonController();
        // Deploy Carbon Batcher
        deployCarbonBatcher(voucher);
    }

    /**
     * @dev construction tests
     */

    function testShouldBeInitializedProperly() public view {
        uint256 version = carbonBatcher.version();
        assertEq(version, 1);
    }

    /**
     * @dev batchCreate tests
     */

    /// @dev test batch create should send strategy NFTs to caller
    function testBatchCreateShouldSendStrategyNFTsToCaller() public {
        vm.startPrank(user1);
        // define strategy data
        StrategyData[] memory strategies = new StrategyData[](2);
        Order[2] memory orders = [generateTestOrder(), generateTestOrder()];
        Token[2] memory tokens = [token0, token1];
        strategies[0] = StrategyData({ tokens: tokens, orders: orders });
        strategies[1] = StrategyData({ tokens: tokens, orders: orders });

        // approve batch router
        token0.safeApprove(address(carbonBatcher), 1e18);
        token1.safeApprove(address(carbonBatcher), 1e18);

        // Create a batch of strategies
        uint256[] memory strategyIds = carbonBatcher.batchCreate(strategies);

        // get strategy ids
        uint256 strategyId0 = generateStrategyId(1, 1);
        uint256 strategyId1 = generateStrategyId(1, 2);

        // Check NFTs have been sent to user1
        uint256[] memory tokenIds = voucher.tokensByOwner(user1, 0, 100);
        assertEq(tokenIds.length, 2);
        assertEq(tokenIds[0], strategyId0);
        assertEq(tokenIds[1], strategyId1);

        assertEq(strategyIds[0], strategyId0);
        assertEq(strategyIds[1], strategyId1);

        vm.stopPrank();
    }

    /// @dev test batch create should refund user for unnecessary native token sent
    function testBatchCreateETHStrategiesShouldRefundUser() public {
        vm.startPrank(user1);
        // define strategy data
        uint128 liquidity = 10000;
        StrategyData[] memory strategies = new StrategyData[](2);
        Order[2] memory orders = [generateTestOrder(liquidity), generateTestOrder(liquidity)];
        Token[2] memory tokens = [token0, NATIVE_TOKEN];
        strategies[0] = StrategyData({ tokens: tokens, orders: orders });
        strategies[1] = StrategyData({ tokens: tokens, orders: orders });

        // approve batch router
        token0.safeApprove(address(carbonBatcher), liquidity * 2);

        // send more value than needed
        uint256 valueToSend = 1e18;

        uint256 userBalanceBefore = address(user1).balance;

        // Create a batch of strategies
        carbonBatcher.batchCreate{ value: valueToSend }(strategies);

        uint256 userBalanceAfter = address(user1).balance;

        // assert user's balance has been refunded
        assertEq(userBalanceAfter, userBalanceBefore - (liquidity * 2));

        vm.stopPrank();
    }

    /// @dev test batch create should return strategy ids
    function testBatchCreateShouldReturnStrategyIds() public {
        vm.startPrank(user1);
        // define strategy data
        StrategyData[] memory strategies = new StrategyData[](10);
        Order[2] memory orders = [generateTestOrder(), generateTestOrder()];
        Token[2] memory tokens = [token0, token1];
        for (uint256 i = 0; i < 10; i++) {
            strategies[i] = StrategyData({ tokens: tokens, orders: orders });
        }

        // approve batch router
        token0.safeApprove(address(carbonBatcher), 1e18);
        token1.safeApprove(address(carbonBatcher), 1e18);

        // Create a batch of strategies
        uint256[] memory strategyIds = carbonBatcher.batchCreate(strategies);

        // get strategy ids
        for (uint256 i = 0; i < 10; i++) {
            uint256 strategyId = generateStrategyId(1, i + 1);
            assertEq(strategyIds[i], strategyId);
        }

        vm.stopPrank();
    }

    /// @dev test batch create should emit strategy created events for each strategy created
    function testBatchCreateStrategiesShouldEmitStrategyCreatedEvents(uint256 strategyCount) public {
        vm.startPrank(user1);
        // create 1 to 10 strategies
        strategyCount = bound(strategyCount, 1, 10);
        // define strategy data
        StrategyData[] memory strategies = new StrategyData[](strategyCount);
        Order[2] memory orders = [generateTestOrder(), generateTestOrder()];
        Token[2] memory tokens = [token0, token1];
        for (uint256 i = 0; i < strategyCount; ++i) {
            strategies[i] = StrategyData({ tokens: tokens, orders: orders });
        }

        // approve batch router
        token0.safeApprove(address(carbonBatcher), 1e18);
        token1.safeApprove(address(carbonBatcher), 1e18);

        // expect controller strategy created events to be emitted in order
        for (uint256 i = 0; i < strategyCount; ++i) {
            uint256 strategyId = generateStrategyId(1, i + 1);
            vm.expectEmit();
            emit StrategyCreated(strategyId, address(carbonBatcher), token0, token1, orders[0], orders[1]);
        }
        // Create a batch of strategies
        carbonBatcher.batchCreate(strategies);

        vm.stopPrank();
    }

    function testBatchCreateShouldEmitBatchCreatedStrategiesEvent(uint256 strategyCount) public {
        vm.startPrank(user1);
        // create 1 to 10 strategies
        strategyCount = bound(strategyCount, 1, 10);
        // define strategy data
        StrategyData[] memory strategies = new StrategyData[](strategyCount);
        Order[2] memory orders = [generateTestOrder(), generateTestOrder()];
        Token[2] memory tokens = [token0, token1];
        for (uint256 i = 0; i < strategyCount; ++i) {
            strategies[i] = StrategyData({ tokens: tokens, orders: orders });
        }

        // approve batch router
        token0.safeApprove(address(carbonBatcher), 1e18);
        token1.safeApprove(address(carbonBatcher), 1e18);

        uint256[] memory strategyIds = new uint256[](strategyCount);

        for (uint256 i = 0; i < strategyCount; ++i) {
            strategyIds[i] = generateStrategyId(1, i + 1);
        }

        // expect to emit batch created strategies event
        vm.expectEmit();
        emit StrategiesCreated(user1, strategyIds);

        // Create a batch of strategies
        carbonBatcher.batchCreate(strategies);

        vm.stopPrank();
    }

    /// @dev test batch create should transfer funds from user to carbon controller
    function testBatchCreateUserShouldTransferFunds(uint128 liquidity0, uint128 liquidity1) public {
        liquidity0 = uint128(bound(liquidity0, 1, MAX_SOURCE_AMOUNT));
        liquidity1 = uint128(bound(liquidity1, 1, MAX_SOURCE_AMOUNT));
        vm.startPrank(user1);
        // define strategy data
        StrategyData[] memory strategies = new StrategyData[](2);
        Order[2] memory orders = [generateTestOrder(liquidity0), generateTestOrder(liquidity1)];
        Token[2] memory tokens = [token0, token1];
        strategies[0] = StrategyData({ tokens: tokens, orders: orders });
        strategies[1] = StrategyData({ tokens: tokens, orders: orders });

        // approve batch router
        token0.safeApprove(address(carbonBatcher), liquidity0 * 2);
        token1.safeApprove(address(carbonBatcher), liquidity1 * 2);

        uint256 token0BalanceBefore = token0.balanceOf(address(user1));
        uint256 token1BalanceBefore = token1.balanceOf(address(user1));

        uint256 token0BalanceBeforeCarbon = token0.balanceOf(address(carbonController));
        uint256 token1BalanceBeforeCarbon = token1.balanceOf(address(carbonController));

        // Create a batch of strategies
        carbonBatcher.batchCreate(strategies);

        uint256 token0BalanceAfter = token0.balanceOf(address(user1));
        uint256 token1BalanceAfter = token1.balanceOf(address(user1));

        uint256 token0BalanceAfterCarbon = token0.balanceOf(address(carbonController));
        uint256 token1BalanceAfterCarbon = token1.balanceOf(address(carbonController));

        // assert user's balance decreases
        assertEq(token0BalanceAfter, token0BalanceBefore - liquidity0 * 2);
        assertEq(token1BalanceAfter, token1BalanceBefore - liquidity1 * 2);

        // assert carbon controller's balance increases
        assertEq(token0BalanceAfterCarbon, token0BalanceBeforeCarbon + liquidity0 * 2);
        assertEq(token1BalanceAfterCarbon, token1BalanceBeforeCarbon + liquidity1 * 2);

        vm.stopPrank();
    }

    /// @dev test batch create should make a single transfer per unique strategy erc-20 token to the carbon batcher
    function testBatchCreateShouldMakeASingleTransferPerUniqueStrategyToken() public {
        vm.startPrank(user1);
        uint128 liquidity = 1000000;
        // define strategy data
        StrategyData[] memory strategies = new StrategyData[](2);
        Order[2] memory orders = [generateTestOrder(liquidity), generateTestOrder(liquidity)];
        Token[2] memory tokens = [token0, token1];
        strategies[0] = StrategyData({ tokens: tokens, orders: orders });
        strategies[1] = StrategyData({ tokens: tokens, orders: orders });

        // approve batch router
        token0.safeApprove(address(carbonBatcher), 1e18);
        token1.safeApprove(address(carbonBatcher), 1e18);

        // expect emit of two transfers - one for each unique token
        // total strategy amounts are summed up for each token
        vm.expectEmit();
        emit Transfer(address(user1), address(carbonBatcher), liquidity * 2);
        vm.expectEmit();
        emit Transfer(address(user1), address(carbonBatcher), liquidity * 2);
        // Create a batch of strategies
        carbonBatcher.batchCreate(strategies);

        vm.stopPrank();
    }

    /// @dev test that batch create reverts if the strategy data is empty
    function testBatchCreateShouldRevertIfCreatedWithEmptyData() public {
        vm.startPrank(user1);
        // define empty strategy data
        StrategyData[] memory strategies = new StrategyData[](0);
        // Create a batch of strategies
        vm.expectRevert(ZeroValue.selector);
        carbonBatcher.batchCreate(strategies);
        vm.stopPrank();
    }

    /// @dev test that batch create reverts if insufficient native token has been sent with the transaction
    function testBatchCreateShouldRevertIfInsufficientETHHasBeenSent() public {
        vm.startPrank(user1);
        // define strategy data
        StrategyData[] memory strategies = new StrategyData[](2);
        uint128 liqudity = 1e18;
        Order[2] memory orders = [generateTestOrder(liqudity), generateTestOrder(liqudity)];
        Token[2] memory tokens = [token0, NATIVE_TOKEN];
        strategies[0] = StrategyData({ tokens: tokens, orders: orders });
        strategies[1] = StrategyData({ tokens: tokens, orders: orders });

        // approve batch router
        token0.safeApprove(address(carbonBatcher), liqudity * 2);

        // Create a batch of strategies
        vm.expectRevert(InsufficientNativeTokenSent.selector);
        carbonBatcher.batchCreate{ value: (liqudity * 2) - 1 }(strategies);

        vm.stopPrank();
    }

    /**
     * @dev admin function tests
     */

    // withdrawFunds tests

    /// @dev test should revert when attempting to withdraw funds without the admin role
    function testShouldRevertWhenAttemptingToWithdrawFundsWithoutTheAdminRole() public {
        vm.prank(user2);
        vm.expectRevert(AccessDenied.selector);
        carbonBatcher.withdrawFunds(token0, user2, 1000);
    }

    /// @dev test should revert when attempting to withdraw funds to an invalid address
    function testShouldRevertWhenAttemptingToWithdrawFundsToAnInvalidAddress() public {
        vm.prank(admin);
        vm.expectRevert(InvalidAddress.selector);
        carbonBatcher.withdrawFunds(token0, payable(address(0)), 1000);
    }

    /// @dev test admin should be able to withdraw funds
    function testAdminShouldBeAbleToWithdrawFunds() public {
        vm.prank(user1);
        // send funds to carbon batcher
        uint256 amount = 1000;
        token0.safeTransfer(address(carbonBatcher), amount);

        vm.startPrank(admin);

        uint256 adminBalanceBefore = token0.balanceOf(address(admin));

        carbonBatcher.withdrawFunds(token0, admin, amount);

        uint256 adminBalanceAfter = token0.balanceOf(address(admin));
        assertEq(adminBalanceAfter, adminBalanceBefore + amount);
        vm.stopPrank();
    }

    // nft withdraw tests

    /// @dev test should revert when attempting to withdraw nft without the admin role
    function testShouldRevertWhenAttemptingToWithdrawNFTWithoutTheAdminRole() public {
        vm.prank(user2);
        vm.expectRevert(AccessDenied.selector);
        carbonBatcher.withdrawNFT(generateStrategyId(1, 1), user2);
    }

    /// @dev test should revert when attempting to withdraw nft to an invalid address
    function testShouldRevertWhenAttemptingToWithdrawNFTToAnInvalidAddress() public {
        vm.prank(admin);
        vm.expectRevert(InvalidAddress.selector);
        carbonBatcher.withdrawNFT(generateStrategyId(1, 1), payable(address(0)));
    }

    /// @dev test admin should be able to withdraw nft
    function testAdminShouldBeAbleToWithdrawNFT() public {
        vm.prank(user1);

        uint256 strategyId = generateStrategyId(1, 1);
        // safe mint an nft to carbon batcher
        voucher.safeMintTest(address(carbonBatcher), strategyId);

        vm.startPrank(admin);

        // assert user1 has no voucher nfts
        uint256[] memory tokenIds = voucher.tokensByOwner(user1, 0, 100);
        assertEq(tokenIds.length, 0);

        // withdraw nft to user1
        carbonBatcher.withdrawNFT(strategyId, user1);

        // assert user1 received the nft
        tokenIds = voucher.tokensByOwner(user1, 0, 100);
        assertEq(tokenIds.length, 1);
        assertEq(tokenIds[0], generateStrategyId(1, 1));
        vm.stopPrank();
    }

    /// @dev helper function to generate test order
    function generateTestOrder() private pure returns (Order memory order) {
        return Order({ y: 800000, z: 8000000, A: 736899889, B: 12148001999 });
    }

    /// @dev helper function to generate test order
    function generateTestOrder(uint128 liquidity) private pure returns (Order memory order) {
        return Order({ y: liquidity, z: liquidity, A: 736899889, B: 12148001999 });
    }

    function generateStrategyId(uint256 pairId, uint256 strategyIndex) private pure returns (uint256) {
        return (pairId << 128) | strategyIndex;
    }
}
