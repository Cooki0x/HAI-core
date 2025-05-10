// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import '@script/Params.s.sol';
import '@script/Registry.s.sol';

import {Script} from 'forge-std/Script.sol';
import {Common} from '@script/Common.s.sol';
import {MainnetParams} from '@script/MainnetParams.s.sol';

/// @dev replace later, or activate BTCN for approval
import {MintableERC20} from '@contracts/for-test/MintableERC20.sol';

abstract contract Deploy is Common, Script {
  function setupEnvironment() public virtual {}
  function setupPostEnvironment() public virtual {}

  function run() public {
    deployer = vm.addr(_deployerPk);
    vm.startBroadcast(deployer);

    // Environment may be different for each network
    setupEnvironment();

    // Common deployment routine for all networks
    deployContracts();
    deployTaxModule();
    _setupContracts();

    // Deploy collateral contracts
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      deployCollateralContracts(_cType);
      _setupCollateral(_cType);
    }

    // Deploy and setup contracts that rely on deployed environment
    setupPostEnvironment();

    vm.stopBroadcast();
  }
}

contract DeployMainnet is MainnetParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('CORN_MAINNET_DEPLOYER_PK'));
  }

  function setupEnvironment() public virtual override updateParams {
    // Set systemCoin
    systemCoin = address(new MintableERC20('BTCN', 'BTCN', 18));

    // Deploy oracle factories
    delayedOracleFactory = new DelayedOracleFactory();

    // Setup oracle feeds
    IBaseOracle _bbqBTCNUSDPriceFeed = new HardcodedOracle('bbqBTCN / USD', BBQ_BTCN_USD_INITIAL_PRICE); // 1 bbqBTCN = 1.1 USD
    delayedOracle[BBQ_BTCN] = delayedOracleFactory.deployDelayedOracle(_bbqBTCNUSDPriceFeed, 1 hours);
    collateral[BBQ_BTCN] = IERC20Metadata(new MintableERC20('bbqBTCN', 'bbqBTCN', 18));
    collateralTypes.push(BBQ_BTCN);

    systemCoinOracle = new HardcodedOracle('BTCN / USD', BTCN_USD_INITIAL_PRICE); // 1 BTCN = 1 USD
  }

  function setupPostEnvironment() public virtual override {}
}
