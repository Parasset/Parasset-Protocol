// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

interface IPTokenFactory {
    function getGovernance() external view returns(address);
    function getPTokenOperator(address contractAddress) external view returns(bool);
    function getPTokenAuthenticity(address pToken) external view returns(bool);
}