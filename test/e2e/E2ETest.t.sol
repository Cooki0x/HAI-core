// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Common, RAD_DELTA} from './Common.t.sol';

import {ILiquidationEngine, ICollateralAuctionHouse} from '@script/Contracts.s.sol';

import {
  INITIAL_DEBT_AUCTION_MINTED_TOKENS,
  ONE_HUNDRED_COINS,
  PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY,
  SURPLUS_AUCTION_BID_RECEIVER
} from '@test/e2e/TestParams.t.sol';

import {Math, RAY, WAD, YEAR} from '@libraries/Math.sol';

import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {Base_CType} from '@test/scopes/Base_CType.t.sol';
import {BBQ_BTCN_CType} from '@test/scopes/BBQ_BTCN_CType.t.sol';

uint256 constant COLLATERAL_AMOUNT = 1e18; // 1
uint256 constant DEBT_AMOUNT = 500e18; // 500 HAI
uint256 constant STABILITY_FEE = RAY + 1.54713e18; // 5%/yr
uint256 constant STABILITY_FEE_APR = 1.05e18; // 5%/yr
uint256 constant LIQUIDATION_C_RATIO = 1.25e27; // 125%
uint256 constant INITIAL_PRICE = 1000e18; // $1000
uint256 constant PRICE_DROP = 100e18; // $100
uint256 constant LIQUIDATION_PENALTY = 1.1e18; // 10%

abstract contract E2ETest is BaseUser, Base_CType, Common {
  using Math for uint256;

  function setUp() public override {
    super.setUp();

    vm.startPrank(deployer); // no governor on test deployment
    taxCollector.modifyParameters('globalStabilityFee', abi.encode(STABILITY_FEE));
    taxCollector.modifyParameters(_cType(), 'stabilityFee', abi.encode(RAY));
    oracleRelayer.modifyParameters(_cType(), 'liquidationCRatio', abi.encode(LIQUIDATION_C_RATIO));
    vm.stopPrank();

    _setCollateralPrice(_cType(), INITIAL_PRICE);
    taxCollector.taxSingle(_cType());
  }

  function test_open_safe() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    (uint256 _generatedDebt, uint256 _lockedCollateral) = _getSafeStatus(_cType(), address(this));
    assertEq(_generatedDebt, DEBT_AMOUNT);
    assertEq(_lockedCollateral, COLLATERAL_AMOUNT);
  }

  function test_exit_collateral() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    _repayDebtAndExit(address(this), address(collateralJoin[_cType()]), COLLATERAL_AMOUNT, DEBT_AMOUNT);

    uint256 _decimals = collateral[_cType()].decimals();
    uint256 _wei = COLLATERAL_AMOUNT / 10 ** (18 - _decimals);
    assertEq(collateralJoin[_cType()].collateral().balanceOf(address(this)), _wei);
  }

  function test_exit_join() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    assertEq(systemCoin.balanceOf(address(this)), DEBT_AMOUNT);
  }

  /*
  function test_stability_fee() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    uint256 _globalDebt;
    _globalDebt = safeEngine.globalDebt();
    assertEq(_globalDebt, DEBT_AMOUNT * RAY); // RAD

    vm.warp(block.timestamp + YEAR);
    taxCollector.taxSingle(_cType());

    uint256 _globalDebtAfterTax = safeEngine.globalDebt();
    assertApproxEqAbs(_globalDebtAfterTax, Math.wmul(DEBT_AMOUNT, STABILITY_FEE_APR) * RAY, RAD_DELTA); // RAD

    uint256 _accountingEngineCoins =
      safeEngine.coinBalance(address(accountingEngine)).rmul(100 * RAY).rdiv(PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY);
    assertEq(_accountingEngineCoins, _globalDebtAfterTax - _globalDebt);
  }
  */

  function test_liquidation() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    _setCollateralPrice(_cType(), PRICE_DROP);

    _liquidateSAFE(_cType(), address(this));

    assertEq(safeEngine.safes(_cType(), address(this)).lockedCollateral, 0);
    assertEq(safeEngine.safes(_cType(), address(this)).generatedDebt, 0);
  }

  /*

  function test_liquidation_by_price_drop() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    // NOTE: LVT for price = 1000 is 50%
    _setCollateralPrice(_cType(), 675e18); // LVT = 74,0% = 1/1.35

    vm.expectRevert(ILiquidationEngine.LiqEng_SAFENotUnsafe.selector);
    _liquidateSAFE(_cType(), address(this));

    _setCollateralPrice(_cType(), 674e18); // LVT = 74,1% > 1/1.35
    _liquidateSAFE(_cType(), address(this));
  }

  function test_liquidation_by_fees() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    _collectFees(_cType(), 8 * YEAR); // 1.05^8 = 148%

    vm.expectRevert(ILiquidationEngine.LiqEng_SAFENotUnsafe.selector);
    _liquidateSAFE(_cType(), address(this));

    _collectFees(_cType(), YEAR); // 1.05^9 = 153%
    _liquidateSAFE(_cType(), address(this));
  }

  function test_collateral_auction_full_sell() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    uint256 _initialBalance = collateral[_cType()].balanceOf(address(this));
    _setCollateralPrice(_cType(), PRICE_DROP);
    _liquidateSAFE(_cType(), address(this));

    uint256 _discount = collateralAuctionHouse[_cType()].params().minDiscount;
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLATERAL_AMOUNT, _discount), PRICE_DROP);
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse[_cType()].getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLATERAL_AMOUNT);

    _buyCollateral(address(this), address(collateralAuctionHouse[_cType()]), 1, _expectedCollateral, _amountToBid);

    uint256 _decimals = collateral[_cType()].decimals();
    uint256 _collateralWei = _expectedCollateral / 10 ** (18 - _decimals);
    assertEq(collateral[_cType()].balanceOf(address(this)) - _initialBalance, _collateralWei);

    // NOTE: auctions(1) is deleted
    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse[_cType()].auctions(1);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);
  }

  function test_collateral_auction_full_raise() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    uint256 _initialBalance = collateral[_cType()].balanceOf(address(this));
    _setCollateralPrice(_cType(), PRICE_DROP);
    _liquidateSAFE(_cType(), address(this));
    _setCollateralPrice(_cType(), INITIAL_PRICE);

    uint256 _amountToBid = Math.wmul(DEBT_AMOUNT, LIQUIDATION_PENALTY);
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse[_cType()].getCollateralBought(1, _amountToBid);
    assertLt(_expectedCollateral, COLLATERAL_AMOUNT);

    _generateDebt(
      address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(_amountToBid - DEBT_AMOUNT)
    );

    _buyCollateral(address(this), address(collateralAuctionHouse[_cType()]), 1, _expectedCollateral, _amountToBid);

    uint256 _decimals = collateral[_cType()].decimals();
    uint256 _collateralWei = _expectedCollateral / 10 ** (18 - _decimals);
    assertEq(collateral[_cType()].balanceOf(address(this)) - _initialBalance, _collateralWei);

    // NOTE: auctions(1) is deleted
    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse[_cType()].auctions(1);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);

    uint256 _remainderCollateral = COLLATERAL_AMOUNT - _expectedCollateral;
    _collateralWei += _remainderCollateral / 10 ** (18 - _decimals);
    _collectTokenCollateral(address(this), address(collateralJoin[_cType()]), _remainderCollateral);
    assertEq(collateral[_cType()].balanceOf(address(this)) - _initialBalance, _collateralWei);
  }

  function test_collateral_auction_partial() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    uint256 _initialBalance = collateral[_cType()].balanceOf(address(this));
    _setCollateralPrice(_cType(), PRICE_DROP);
    _liquidateSAFE(_cType(), address(this));

    uint256 _discount = collateralAuctionHouse[_cType()].params().minDiscount;
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLATERAL_AMOUNT, _discount), PRICE_DROP) / 2;
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse[_cType()].getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLATERAL_AMOUNT / 2);

    _buyCollateral(address(this), address(collateralAuctionHouse[_cType()]), 1, _expectedCollateral, _amountToBid);

    uint256 _decimals = collateral[_cType()].decimals();
    uint256 _collateralWei = _expectedCollateral / 10 ** (18 - _decimals);
    assertEq(collateral[_cType()].balanceOf(address(this)) - _initialBalance, _collateralWei);

    // NOTE: auctions(1) is NOT deleted
    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse[_cType()].auctions(1);
    assertGt(_auction.amountToSell, 0);
    assertGt(_auction.amountToRaise, 0);
  }
  */
}

// --- Scoped test contracts ---

// NOTE: ETH tests not implemented (fails on exit bc of fallback)

contract E2ETestDirectUserBBQ_BTCN is DirectUser, BBQ_BTCN_CType, E2ETest {}
