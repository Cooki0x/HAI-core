// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Contracts} from '@script/Contracts.s.sol';

import {
  IBaseOracle,
  IAccountingEngine,
  ICollateralAuctionHouse,
  IOracleRelayer,
  ISAFEEngine,
  ILiquidationEngine,
  IStabilityFeeTreasury,
  ITaxCollector,
  IModifiable
} from '@script/Contracts.s.sol';

import {WAD, RAY, RAD} from '@libraries/Math.sol';

// --- Utils ---

// HAI Params
bytes32 constant BTCN = bytes32('BTCN');
uint256 constant BTCN_USD_INITIAL_PRICE = 1e18; // 1 BTCN = 1 USD

// Collateral Names
bytes32 constant BBQ_BTCN = bytes32('BBQ_BTCN');
uint256 constant BBQ_BTCN_USD_INITIAL_PRICE = 1.1e18; // 1 bbqBTCN = 1.1 USD

// Original Wrong Value
uint256 constant MINUS_10_PERCENT_IN_2_HOURS = 999_985_366_702_115_272_120_527_460;
// Correct Value
// bc -l <<< 'scale=27; e( l(.9)/(60 * 60 * 2) )'
// uint256 constant MINUS_10_PERCENT_IN_2_HOURS_CORRECT = 999_985_366_702_115_272_120_527_461;

// bc -l <<< 'scale=27; e( l(.85)/(60 * 60 * 2) )'
uint256 constant MINUS_15_PERCENT_IN_2_HOURS = 999_977_428_181_205_977_622_596_568;

// bc -l <<< 'scale=27; e( l(.995)/(60 * 60 * 1) )'
uint256 constant MINUS_0_5_PERCENT_PER_HOUR = 999_998_607_628_240_588_157_433_861;

// bc -l <<< 'scale=27; e( l(.99)/(60 * 60 * 1) )'
uint256 constant MINUS_1_PERCENT_PER_HOUR = 999_997_208_243_937_652_252_849_536;

// Original Wrong Value
uint256 constant MINUS_90_PERCENT_PER_YEAR = 99_999_999_999_997_789_272_222_624;
// Correct Value
// bc -l <<< 'scale=27; e( l(.1)/(60 * 60 * 24 * 365) )'
uint256 constant MINUS_90_PERCENT_PER_YEAR_CORRECT = 999_999_926_985_508_341_799_701_018;

// bc -l <<< 'scale=27; e( l(.5)/(60 * 60 * 24 * 30) )'
uint256 constant HALF_LIFE_30_DAYS = 999_999_732_582_142_021_614_955_959;

// bc -l <<< 'scale=27; e( l(1.015)/(60 * 60 * 24 * 365) )'
uint256 constant PLUS_1_5_PERCENT_PER_YEAR = 1_000_000_000_472_114_805_215_157_978;

// bc -l <<< 'scale=27; e( l(1.02)/(60 * 60 * 24 * 365) )'
uint256 constant PLUS_2_PERCENT_PER_YEAR = 1_000_000_000_627_937_192_491_029_810;

// bc -l <<< 'scale=27; e( l(1.05)/(60 * 60 * 24 * 365) )'
uint256 constant PLUS_5_PERCENT_PER_YEAR = 1_000_000_001_547_125_957_863_212_448;

// bc -l <<< 'scale=27; e( l(10.5)/(60 * 60 * 24 * 365) )' > 2 -> + 100% ~ 10.5 ~ + 950%
uint256 constant PLUS_950_PERCENT_PER_YEAR = 1_000_000_074_561_623_060_142_516_377;

// NOTE: RAI values are imported from https://etherscan.io/address/0x5CC4878eA3E6323FdA34b3D28551E1543DEe54C6
// uint256 constant PROPORTIONAL_GAIN = 111_001_102_931; // 50% of RAI's
// uint256 constant INTEGRAL_GAIN = 32_884; // 200% of RAI's

// NOTE: HAI values are determined from this proposal: https://www.tally.xyz/gov/hai/proposal/32479302120926519766179048244685655250705286874030325872305136895885783434706

// Set the controller Kp term to 1.54712579996991E-07
// 1.54712579996991E-07
// 0.000000154712579996991
// 0.000000154712579996991 * 10 ^ 18 = 154712579996.991 ~ 154712579997
uint256 constant PROPORTIONAL_GAIN = 154_712_579_997;

// Set the controller Ki term to 1.37853553658453E-14
// 1.37853553658453E-14
// 0.0000000000000137853553658453E-14
// 0.0000000000000137853553658453 * 10 ^ 18 = 13785.3553658453 ~ 13785
uint256 constant INTEGRAL_GAIN = 13_785;

// Job Params
uint256 constant JOB_REWARD = 1 * WAD; // 1 HAI

/**
 * @title Params
 * @notice This contract initializes all the contract parameters structs, so that they're inherited and available throughout scripts scopes.
 */
abstract contract Params {
  /**
   * @notice Initializes the parameters of the contracts, as many depend on the contracts addresses and need to be dynamically loaded.
   */
  function _getEnvironmentParams() internal virtual;

  // --- Contracts params ---

  ISAFEEngine.SAFEEngineParams _safeEngineParams;
  mapping(bytes32 => ISAFEEngine.SAFEEngineCollateralParams) _safeEngineCParams;

  IOracleRelayer.OracleRelayerParams _oracleRelayerParams;
  mapping(bytes32 => IOracleRelayer.OracleRelayerCollateralParams) _oracleRelayerCParams;

  IAccountingEngine.AccountingEngineParams _accountingEngineParams;
  ILiquidationEngine.LiquidationEngineParams _liquidationEngineParams;
  mapping(bytes32 => ILiquidationEngine.LiquidationEngineCollateralParams) _liquidationEngineCParams;
  mapping(bytes32 => ICollateralAuctionHouse.CollateralAuctionHouseParams) _collateralAuctionHouseParams;

  IStabilityFeeTreasury.StabilityFeeTreasuryParams _stabilityFeeTreasuryParams;
  ITaxCollector.TaxCollectorParams _taxCollectorParams;
  mapping(bytes32 => ITaxCollector.TaxCollectorCollateralParams) _taxCollectorCParams;
  ITaxCollector.TaxReceiver[] _taxCollectorSecondaryTaxReceiver;
}

/**
 * @title ParamChecker
 * @notice This library sets the parameters of the contracts, one by one, ensuring that they're set fully and correctly.
 */
library ParamChecker {
  // --- Helper functions ---

  function _checkParams(address _modifiable, bytes memory _params) internal view {
    bytes memory _callData = abi.encodeWithSignature('params()');
    (, bytes memory _returnData) = _modifiable.staticcall(_callData);

    bytes memory _empty = new bytes(_params.length);

    require(keccak256(_params) != keccak256(_empty), 'Empty params');
    require(keccak256(_params) == keccak256(_returnData), 'Incorrect params');
  }

  function _checkCParams(address _modifiable, bytes32 _cType, bytes memory _cParams) internal view {
    bytes memory _callData = abi.encodeWithSignature('cParams(bytes32)', _cType);
    (, bytes memory _returnData) = _modifiable.staticcall(_callData);

    bytes memory _empty = new bytes(_cParams.length);

    require(keccak256(_cParams) != keccak256(_empty), 'Empty params');
    require(keccak256(_cParams) == keccak256(_returnData), 'Incorrect params');
  }
}
