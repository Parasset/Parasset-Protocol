// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

interface IMortgagePool {
    function create(address pToken, address insurance, address underlying) external;
}