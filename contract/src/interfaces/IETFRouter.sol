// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IETFCore} from "./IETFCore.sol";

/**
 * @title IETFRouter
 * @author
 * @notice
 * router合约，用于将用户USDT兑换为底层资产，并铸造份额给用户
 */

interface IETFRouter is IETFCore {
    error InvalidSwapPath(bytes swapPath);
    error InvalidArrayLength();
    error OverSlippage();
    error SafeTransferETHFailed();

    event InvestedWithETH(address to, uint256 mintAmount, uint256 paidAmount);
    event InvestedWithToken(
        address indexed srcToken,
        address to,
        uint256 mintAmount,
        uint256 totalPaid
    );
    event RedeemedToETH(address to, uint256 burnAmount, uint256 receivedAmount);
    event RedeemedToToken(
        address indexed dstToken,
        address to,
        uint256 burnAmount,
        uint256 receivedAmount
    );

    function investWithETH(
        address to,
        uint256 mintAmount,
        bytes[] memory swapPaths
    ) external payable;

    function investWithToken(
        address srcToken,
        address to,
        uint256 mintAmount,
        uint256 maxSrcTokenAmount,
        bytes[] memory swapPaths
    ) external;

    function redeemToETH(
        address to,
        uint256 burnAmount,
        uint256 minETHAmount,
        bytes[] memory swapPaths
    ) external;

    function redeemToToken(
        address dstToken,
        address to,
        uint256 burnAmount,
        uint256 minDstTokenAmount,
        bytes[] memory swapPaths
    ) external;

    function swapRouter() external view returns (address);

    function weth() external view returns (address);
}
