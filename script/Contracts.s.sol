// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

// --- Base Contracts ---
import {SAFEEngine, ISAFEEngine} from '@contracts/SAFEEngine.sol';
import {TaxCollector, ITaxCollector} from '@contracts/TaxCollector.sol';
import {AccountingEngine, IAccountingEngine} from '@contracts/AccountingEngine.sol';
import {LiquidationEngine, ILiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {CollateralAuctionHouse, ICollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {StabilityFeeTreasury, IStabilityFeeTreasury} from '@contracts/StabilityFeeTreasury.sol';

// --- Oracles ---
import {OracleRelayer, IOracleRelayer} from '@contracts/OracleRelayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {DelayedOracle, IDelayedOracle} from '@contracts/oracles/DelayedOracle.sol';
import {DenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {ChainlinkRelayer} from '@contracts/oracles/ChainlinkRelayer.sol';
import {UniV3Relayer, IUniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';

// --- Testnet contracts ---
import {MintableERC20} from '@contracts/for-test/MintableERC20.sol';
import {DeviatedOracle} from '@contracts/for-test/DeviatedOracle.sol';
import {HardcodedOracle} from '@contracts/for-test/HardcodedOracle.sol';

// --- Token adapters ---
import {CoinJoin, ICoinJoin} from '@contracts/utils/CoinJoin.sol';
import {CollateralJoin, ICollateralJoin} from '@contracts/utils/CollateralJoin.sol';

// --- Factories ---
import {CollateralJoinFactory, ICollateralJoinFactory} from '@contracts/factories/CollateralJoinFactory.sol';
import {
  CollateralAuctionHouseFactory,
  ICollateralAuctionHouseFactory
} from '@contracts/factories/CollateralAuctionHouseFactory.sol';
import {ChainlinkRelayerFactory, IChainlinkRelayerFactory} from '@contracts/factories/ChainlinkRelayerFactory.sol';
import {UniV3RelayerFactory, IUniV3RelayerFactory} from '@contracts/factories/UniV3RelayerFactory.sol';
import {DenominatedOracleFactory, IDenominatedOracleFactory} from '@contracts/factories/DenominatedOracleFactory.sol';
import {DelayedOracleFactory, IDelayedOracleFactory} from '@contracts/factories/DelayedOracleFactory.sol';

// --- Interfaces ---
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {IUniswapV3Pool} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

/**
 * @title  Contracts
 * @notice This contract initializes all the contracts, so that they're inherited and available throughout scripts scopes.
 * @dev    It exports all the contracts and interfaces to be inherited or modified during the scripts dev and execution.
 */
abstract contract Contracts {
  // --- Helpers ---
  address public deployer;
  address public governor;
  address public delegate;
  bytes32[] public collateralTypes;
  mapping(bytes32 => address) public delegatee;

  // --- Base contracts ---
  ISAFEEngine public safeEngine;
  ITaxCollector public taxCollector;
  IAccountingEngine public accountingEngine;
  ILiquidationEngine public liquidationEngine;
  IOracleRelayer public oracleRelayer;
  IStabilityFeeTreasury public stabilityFeeTreasury;
  mapping(bytes32 => ICollateralAuctionHouse) public collateralAuctionHouse;

  // --- Token contracts ---
  MintableERC20 public systemCoin;
  mapping(bytes32 => IERC20Metadata) public collateral;
  ICoinJoin public coinJoin;
  mapping(bytes32 => ICollateralJoin) public collateralJoin;

  // --- Oracle contracts ---
  IBaseOracle public systemCoinOracle;
  mapping(bytes32 => IDelayedOracle) public delayedOracle;

  // --- Factory contracts ---
  ICollateralJoinFactory public collateralJoinFactory;
  ICollateralAuctionHouseFactory public collateralAuctionHouseFactory;

  IChainlinkRelayerFactory public chainlinkRelayerFactory;
  IUniV3RelayerFactory public uniV3RelayerFactory;
  IDenominatedOracleFactory public denominatedOracleFactory;
  IDelayedOracleFactory public delayedOracleFactory;
}
