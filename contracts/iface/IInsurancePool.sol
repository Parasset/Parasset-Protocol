// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

interface IInsurancePool {
    function setPTokenToIns(address pToken, address ins) external;
    function destroyPToken(address pToken, uint256 amount) external;
    function eliminate(address pToken) external;
}