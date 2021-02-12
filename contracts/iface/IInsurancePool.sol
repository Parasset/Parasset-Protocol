// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

interface IInsurancePool {
    function setPTokenToIns(address pToken, address ins) external;
    function destroyPToken(address pToken, uint256 amount, address token) external;
    function eliminate(address pToken, address token) external;
    function setLatestTime(address token) external;
}