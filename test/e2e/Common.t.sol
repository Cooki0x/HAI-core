// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {DeployMainnet} from '@script/Deploy.s.sol';
import {
  Contracts, ICollateralJoin, MintableERC20, IERC20Metadata, IBaseOracle, ISAFEEngine
} from '@script/Contracts.s.sol';
import {Math, RAY} from '@libraries/Math.sol';

uint256 constant RAD_DELTA = 0.0001e45;
uint256 constant COLLATERAL_PRICE = 100e18;

uint256 constant COLLAT = 1e18;
uint256 constant DEBT = 500e18; // LVT 50%
uint256 constant TEST_ETH_PRICE_DROP = 100e18; // 1 ETH = 100 HAI

/**
 * @title  Common
 * @notice Abstract contract that contains for test methods, and triggers DeployForTest routine
 * @dev    Used to be inherited by different test contracts with different scopes
 */
abstract contract Common is DeployMainnet, HaiTest {
  address alice = address(0x420);
  address bob = address(0x421);
  address carol = address(0x422);
  address dave = address(0x423);

  function setUp() public virtual override {
    vm.createSelectFork(vm.rpcUrl('corn'));
    run();

    vm.label(deployer, 'Deployer');
    vm.label(alice, 'Alice');
    vm.label(bob, 'Bob');
    vm.label(carol, 'Carol');
    vm.label(dave, 'Dave');
  }

  function _setCollateralPrice(bytes32 _collateral, uint256 _price) internal {
    IBaseOracle _oracle = oracleRelayer.cParams(_collateral).oracle;
    vm.mockCall(
      address(_oracle), abi.encodeWithSelector(IBaseOracle.getResultWithValidity.selector), abi.encode(_price, true)
    );
    vm.mockCall(address(_oracle), abi.encodeWithSelector(IBaseOracle.read.selector), abi.encode(_price));
    oracleRelayer.updateCollateralPrice(_collateral);
  }

  function _collectFees(bytes32 _cType, uint256 _timeToWarp) internal {
    vm.warp(block.timestamp + _timeToWarp);
    taxCollector.taxSingle(_cType);
  }
}
