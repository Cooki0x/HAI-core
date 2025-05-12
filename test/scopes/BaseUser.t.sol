// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title  BaseUser
 * @notice Abstract contract containing all methods to interact with the system
 * @dev    Used to override it with different implementations (e.g. ProxyUser, DirectUser)
 */
abstract contract BaseUser {
  function _getSafeStatus(
    bytes32 _cType,
    address _user
  ) internal virtual returns (uint256 _generatedDebt, uint256 _lockedCollateral);

  function _getSafeHandler(bytes32 _cType, address _user) internal virtual returns (address _safeHandler);

  function _getCollateralBalance(address _user, bytes32 _cType) internal view virtual returns (uint256 _wad);

  function _getInternalCoinBalance(address _user) internal virtual returns (uint256 _rad);

  // --- SAFE actions ---

  function _joinCoins(address _user, uint256 _amount) internal virtual;

  function _exitCoins(address _user, uint256 _amount) internal virtual;

  function _exitAllCoins(address _user) internal virtual;

  function _joinTKN(address _user, address _collateralJoin, uint256 _amount) internal virtual;

  function _exitCollateral(address _user, address _collateralJoin, uint256 _amount) internal virtual;

  function _liquidateSAFE(bytes32 _cType, address _user) internal virtual;

  function _generateDebt(
    address _user,
    address _collateralJoin,
    int256 _deltaCollat,
    int256 _deltaDebt
  ) internal virtual;

  function _repayDebtAndExit(
    address _user,
    address _collateralJoin,
    uint256 _deltaCollat,
    uint256 _deltaDebt
  ) internal virtual;

  function _collectTokenCollateral(address _user, address _collateralJoin, uint256 _amount) internal virtual;

  // --- Bidding actions ---

  function _buyCollateral(
    address _user,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _soldAmount,
    uint256 _amountToBid
  ) internal virtual;
}
