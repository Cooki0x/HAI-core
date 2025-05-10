// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Test} from 'forge-std/Test.sol';
import {DeployMainnet} from '@script/Deploy.s.sol';

contract Base is Test, DeployMainnet {
  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('corn'));
    run();
  }

  function testInit() external {}
}
