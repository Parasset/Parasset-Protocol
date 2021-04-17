// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.6.12;

///@dev This interface defines the methods for ntoken management
interface INTokenController {
    /// @dev Get ntoken address from token address
    /// @param tokenAddress Destination token address
    /// @return ntoken address
    function getNTokenAddress(address tokenAddress) external view returns (address);
}