// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Params.s.sol';
import '@script/Registry.s.sol';

abstract contract MainnetParams is Contracts, Params {
  // --- Corn Params ---
  function _getEnvironmentParams() internal override {
    _safeEngineParams = ISAFEEngine.SAFEEngineParams({
      safeDebtCeiling: 1_000_000 * WAD, // WAD
      globalDebtCeiling: 55_000_000 * RAD // initially disabled
    });

    _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusIsTransferred: 0, // surplus is auctioned
      surplusDelay: 1 days,
      popDebtDelay: 14 days,
      disableCooldown: 3 days,
      surplusAmount: 42_000 * RAD, // 42k HAI
      surplusBuffer: 100_000 * RAD, // 100k HAI
      debtAuctionMintedTokens: 10_000 * WAD, // 10k KITE
      debtAuctionBidSize: 10_000 * RAD // 10k HAI
    });

    _liquidationEngineParams = ILiquidationEngine.LiquidationEngineParams({
      onAuctionSystemCoinLimit: 10_000_000 * RAD, // 10M HAI
      saviourGasLimit: 10_000_000 // 10M gas
    });

    _stabilityFeeTreasuryParams = IStabilityFeeTreasury.StabilityFeeTreasuryParams({
      treasuryCapacity: 1_000_000 * RAD, // 1M HAI
      pullFundsMinThreshold: 0, // no threshold
      surplusTransferDelay: 1 days
    });

    _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(accountingEngine),
      globalStabilityFee: RAY, // no global SF
      maxStabilityFeeRange: RAY - MINUS_0_5_PERCENT_PER_HOUR, // +- 0.5% per hour
      maxSecondaryReceivers: 5
    });

    delete _taxCollectorSecondaryTaxReceiver; // avoid stacking old data on each push

    _taxCollectorSecondaryTaxReceiver.push(
      ITaxCollector.TaxReceiver({
        receiver: address(stabilityFeeTreasury),
        canTakeBackTax: true, // [bool]
        taxPercentage: 0.2e18 // 20%
      })
    );

    _taxCollectorSecondaryTaxReceiver.push(
      ITaxCollector.TaxReceiver({
        receiver: CORN_ADMIN_SAFE,
        canTakeBackTax: true, // [bool]
        taxPercentage: 0.21e18 // 21%
      })
    );

    // --- PID Params ---

    _oracleRelayerParams = IOracleRelayer.OracleRelayerParams({
      redemptionRateUpperBound: PLUS_950_PERCENT_PER_YEAR, // +950%/yr
      redemptionRateLowerBound: MINUS_90_PERCENT_PER_YEAR // -90%/yr
    });

    // --- Collateral Specific Params ---
    // ------------ BBQ_BTCN ------------
    _safeEngineCParams[BBQ_BTCN] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 25_000_000 * RAD, // 25M HAI
      debtFloor: 150 * RAD // 150 HAI
    });

    _oracleRelayerCParams[BBQ_BTCN] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: delayedOracle[BBQ_BTCN],
      safetyCRatio: 1.3e27, // 130%
      liquidationCRatio: 1.25e27 // 125%
    });

    _taxCollectorCParams[BBQ_BTCN].stabilityFee = PLUS_1_5_PERCENT_PER_YEAR; // 1.5%/yr

    _liquidationEngineCParams[BBQ_BTCN] = ILiquidationEngine.LiquidationEngineCollateralParams({
      collateralAuctionHouse: address(collateralAuctionHouse[BBQ_BTCN]),
      liquidationPenalty: 1.1e18, // 10%
      liquidationQuantity: 50_000 * RAD // 50k HAI
    });

    _collateralAuctionHouseParams[BBQ_BTCN] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: 100 * WAD, // 100 HAI
      minDiscount: 1e18, // no discount
      maxDiscount: 0.9e18, // -10%
      perSecondDiscountUpdateRate: MINUS_10_PERCENT_IN_2_HOURS // -10% / 2hs
    });
  }
}
