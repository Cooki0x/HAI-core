// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import '@script/Params.s.sol';
import '@script/Registry.s.sol';

import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';

abstract contract Common is Contracts, Params {
  uint256 internal _deployerPk = 69; // for tests

  function deployContracts() public updateParams {
    // deploy Base contracts
    safeEngine = new SAFEEngine(_safeEngineParams);

    oracleRelayer = new OracleRelayer(address(safeEngine), systemCoinOracle, _oracleRelayerParams);

    /// @dev passes safeEngine as debt and suprlus houses - fix later
    accountingEngine =
      new AccountingEngine(address(safeEngine), address(safeEngine), address(safeEngine), _accountingEngineParams);

    liquidationEngine = new LiquidationEngine(address(safeEngine), address(accountingEngine), _liquidationEngineParams);

    collateralAuctionHouseFactory =
      new CollateralAuctionHouseFactory(address(safeEngine), address(liquidationEngine), address(oracleRelayer));

    // deploy Token adapters
    coinJoin = new CoinJoin(address(safeEngine), address(systemCoin));

    collateralJoinFactory = new CollateralJoinFactory(address(safeEngine));
  }

  function deployTaxModule() public updateParams {
    taxCollector = new TaxCollector(address(safeEngine), _taxCollectorParams);

    stabilityFeeTreasury = new StabilityFeeTreasury(
      address(safeEngine), address(accountingEngine), address(coinJoin), _stabilityFeeTreasuryParams
    );
  }

  function _setupContracts() internal {
    // auth
    safeEngine.addAuthorization(address(oracleRelayer)); // modifyParameters
    safeEngine.addAuthorization(address(coinJoin)); // transferInternalCoins
    safeEngine.addAuthorization(address(taxCollector)); // updateAccumulatedRate
    safeEngine.addAuthorization(address(liquidationEngine)); // confiscateSAFECollateralAndDebt
    accountingEngine.addAuthorization(address(liquidationEngine)); // pushDebtToQueue
    /// @dev need to let coinjoin mint some
    //systemCoin.addAuthorization(address(coinJoin)); // mint

    safeEngine.addAuthorization(address(collateralJoinFactory)); // addAuthorization(cJoin child)
  }

  function deployCollateralContracts(bytes32 _cType) public updateParams {
    // deploy CollateralJoin and CollateralAuctionHouse
    address _delegatee = delegatee[_cType];
    if (_delegatee == address(0)) {
      collateralJoin[_cType] =
        collateralJoinFactory.deployCollateralJoin({_cType: _cType, _collateral: address(collateral[_cType])});
    } else {
      collateralJoin[_cType] = collateralJoinFactory.deployDelegatableCollateralJoin({
        _cType: _cType,
        _collateral: address(collateral[_cType]),
        _delegatee: _delegatee
      });
    }

    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(_collateralAuctionHouseParams[_cType]));
    collateralAuctionHouse[_cType] =
      ICollateralAuctionHouse(collateralAuctionHouseFactory.collateralAuctionHouses(_cType));
  }

  function _setupCollateral(bytes32 _cType) internal {
    safeEngine.initializeCollateralType(_cType, abi.encode(_safeEngineCParams[_cType]));
    oracleRelayer.initializeCollateralType(_cType, abi.encode(_oracleRelayerCParams[_cType]));
    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liquidationEngineCParams[_cType]));

    taxCollector.initializeCollateralType(_cType, abi.encode(_taxCollectorCParams[_cType]));

    for (uint256 _i; _i < _taxCollectorSecondaryTaxReceiver.length; _i++) {
      taxCollector.modifyParameters(_cType, 'secondaryTaxReceiver', abi.encode(_taxCollectorSecondaryTaxReceiver[_i]));
    }

    // setup initial price
    oracleRelayer.updateCollateralPrice(_cType);
  }

  function _deployUniV3Pool(
    address _uniV3Factory,
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    uint16 _cardinality,
    int24 _initialTick
  ) internal {
    address _uniV3Pool = IUniswapV3Factory(_uniV3Factory).getPool(_tokenA, _tokenB, _fee);
    if (_uniV3Pool == address(0)) {
      _uniV3Pool = IUniswapV3Factory(_uniV3Factory).createPool({tokenA: _tokenA, tokenB: _tokenB, fee: _fee});
    }

    address _token0 = IUniswapV3Pool(_uniV3Pool).token0();
    uint160 _sqrtPriceX96 = _token0 == address(_tokenA)
      ? TickMath.getSqrtRatioAtTick(_initialTick)
      : TickMath.getSqrtRatioAtTick(-_initialTick);

    IUniswapV3Pool(_uniV3Pool).initialize(_sqrtPriceX96);

    for (uint256 _i = 500; _i <= _cardinality; _i += 500) {
      IUniswapV3Pool(_uniV3Pool).increaseObservationCardinalityNext(uint16(_i));
    }
    if (_cardinality % 500 != 0) {
      IUniswapV3Pool(_uniV3Pool).increaseObservationCardinalityNext(_cardinality);
    }
  }

  function _revokeDeployerToAll(address _governor) internal {
    if (!_shouldRevoke()) return;

    _toAllAuthorizableContracts(_revokeDeployerTo, _governor);
  }

  function _revokeDeployerTo(IAuthorizable _contract, address _governor) internal {
    _contract.addAuthorization(_governor);
    _contract.removeAuthorization(deployer);
  }

  function _shouldRevoke() internal view returns (bool) {
    return governor != deployer && governor != address(0);
  }

  function _delegateToAll(address _delegate) internal {
    _toAllAuthorizableContracts(_delegateTo, _delegate);
  }

  function _delegateTo(IAuthorizable _contract, address _delegate) internal {
    _contract.addAuthorization(_delegate);
  }

  function _toAllAuthorizableContracts(function (IAuthorizable, address) internal _function, address _target) internal {
    // base contracts
    _function(safeEngine, _target);
    _function(liquidationEngine, _target);
    _function(accountingEngine, _target);
    _function(oracleRelayer, _target);

    // tax
    _function(taxCollector, _target);
    _function(stabilityFeeTreasury, _target);

    // token adapters
    _function(coinJoin, _target);

    // factories or children
    // NOTE: not deployable on Sepolia testnet
    if (address(chainlinkRelayerFactory) != address(0)) _function(chainlinkRelayerFactory, _target);
    if (address(uniV3RelayerFactory) != address(0)) _function(uniV3RelayerFactory, _target);
    _function(denominatedOracleFactory, _target);
    _function(delayedOracleFactory, _target);

    _function(collateralJoinFactory, _target);
    _function(collateralAuctionHouseFactory, _target);
  }

  modifier updateParams() {
    _getEnvironmentParams();
    _;
    _getEnvironmentParams();
  }
}
