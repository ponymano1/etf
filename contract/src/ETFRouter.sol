// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ETFCore} from "./ETFCore.sol";
import {IETFRouter} from "./interfaces/IETFRouter.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {Path} from "./libraries/Path.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IV3SwapRouter} from "./interfaces/IV3SwapRouter.sol";

/**
 * Router合约，用于将用户USDT兑换为底层资产，并铸造份额给用户
 * 支持通过ETH或Token兑换
 * 支持通过V2或V3的DEX进行兑换
 */
contract ETFRouter is IETFRouter, ETFCore {
    using SafeERC20 for IERC20;
    using Path for bytes;

    address public immutable swapRouter;
    address public immutable weth;

    constructor(
        string memory name_,
        string memory symbol_,
        address[] memory tokens_,
        uint256[] memory initTokenAmountPerShare_,
        uint256 minMintAmount_,
        address swapRouter_,
        address weth_
    ) ETFv1(name_, symbol_, tokens_, initTokenAmountPerShare_, minMintAmount_) {
        swapRouter = swapRouter_;
        weth = weth_;
    }

    receive() external payable {}

    function investWithETH(
        address to,
        uint256 mintAmount,
        bytes[] memory swapPaths
    ) external payable {
        address[] memory tokens = getTokens();
        if (tokens.length != swapPaths.length) revert InvalidArrayLength();

        uint256[] memory tokenAmounts = getInvestTokenAmounts(mintAmount);

        uint256 maxETHAmount = msg.value;
        IWETH(weth).deposit{value: maxETHAmount}();
        _approveToSwapRouter(weth);

        uint256 totalPaid;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokenAmounts[i] == 0) continue;
            if (!_checkSwapPath(tokens[i], weth, swapPaths[i]))
                revert InvalidSwapPath(swapPaths[i]);
            if (tokens[i] == weth) {
                totalPaid += tokenAmounts[i];
            } else {
                totalPaid += IV3SwapRouter(swapRouter).exactOutput(
                    IV3SwapRouter.ExactOutputParams({
                        path: swapPaths[i],
                        recipient: address(this),
                        amountOut: tokenAmounts[i],
                        amountInMaximum: type(uint256).max
                    })
                );
            }
        }

        uint256 leftAfterPaid = maxETHAmount - totalPaid;
        IWETH(weth).withdraw(leftAfterPaid);
        payable(msg.sender).transfer(leftAfterPaid);

        _invest(to, mintAmount);

        emit InvestedWithETH(to, mintAmount, totalPaid);
    }

    /**
     * 通过Token兑换为底层资产，并铸造份额给用户
     * 过程:
     * 1. 计算需要的每个token的数量
     * 2. 转移token到合约  注意：invest with all tokens, msg.sender need have approved all tokens to this contract
     * 3. 循环每个token，交易出需要的token到合约
     * 4. 计算需要返还的token数量（没有用完的token）
     * 5. 调用ETFCore的_invest内部函数，铸造份额给用户，并收取手续费
     */
    function investWithToken(
        address srcToken,
        address to,
        uint256 mintAmount,
        uint256 maxSrcTokenAmount, //包含滑点保护的token数量
        bytes[] memory swapPaths
    ) external {
        address[] memory tokens = getTokens();
        if (tokens.length != swapPaths.length) revert InvalidArrayLength();
        uint256[] memory tokenAmounts = getInvestTokenAmounts(mintAmount);
        //转移token到合约
        IERC20(srcToken).safeTransferFrom(
            msg.sender,
            address(this),
            maxSrcTokenAmount
        );
        _approveToSwapRouter(srcToken);

        uint256 totalPaid; //总共需要支付的token数量
        //循环每个token，交易出需要的token到合约
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokenAmounts[i] == 0) continue;
            if (!_checkSwapPath(tokens[i], srcToken, swapPaths[i]))
                revert InvalidSwapPath(swapPaths[i]);
            if (tokens[i] == srcToken) {
                totalPaid += tokenAmounts[i];
            } else {
                totalPaid += IV3SwapRouter(swapRouter).exactOutput(
                    IV3SwapRouter.ExactOutputParams({
                        path: swapPaths[i],
                        recipient: address(this),
                        amountOut: tokenAmounts[i],
                        amountInMaximum: type(uint256).max
                    })
                );
            }
        }
        //计算需要返还的token数量（没有用完的token）
        uint256 leftAfterPaid = maxSrcTokenAmount - totalPaid;
        IERC20(srcToken).safeTransfer(msg.sender, leftAfterPaid);

        _invest(to, mintAmount);

        emit InvestedWithToken(srcToken, to, mintAmount, totalPaid);
    }

    function redeemToETH(
        address to,
        uint256 burnAmount,
        uint256 minETHAmount,
        bytes[] memory swapPaths
    ) external {
        address[] memory tokens = getTokens();
        if (tokens.length != swapPaths.length) revert InvalidArrayLength();

        uint256[] memory tokenAmounts = _redeem(address(this), burnAmount);

        uint256 totalReceived;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokenAmounts[i] == 0) continue;
            if (!_checkSwapPath(tokens[i], weth, swapPaths[i]))
                revert InvalidSwapPath(swapPaths[i]);
            if (tokens[i] == weth) {
                totalReceived += tokenAmounts[i];
            } else {
                _approveToSwapRouter(tokens[i]);
                totalReceived += IV3SwapRouter(swapRouter).exactInput(
                    IV3SwapRouter.ExactInputParams({
                        path: swapPaths[i],
                        recipient: address(this),
                        amountIn: tokenAmounts[i],
                        amountOutMinimum: 1
                    })
                );
            }
        }

        if (totalReceived < minETHAmount) revert OverSlippage();
        IWETH(weth).withdraw(totalReceived);
        _safeTransferETH(to, totalReceived);

        emit RedeemedToETH(to, burnAmount, totalReceived);
    }

    /**
     * 通过底层资产兑换为Token，并返还给用户
     * 过程:
     * 1. 调用ETFCore的_redeem内部函数，销毁份额给用户，并收取手续费
     * 2. 循环每个token，交易出需要的token到用户
     * 3. 判断是否满足滑点要求
     *
     */
    function redeemToToken(
        address dstToken,
        address to,
        uint256 burnAmount,
        uint256 minDstTokenAmount,
        bytes[] memory swapPaths
    ) external {
        address[] memory tokens = getTokens();
        if (tokens.length != swapPaths.length) revert InvalidArrayLength();

        uint256[] memory tokenAmounts = _redeem(address(this), burnAmount);

        uint256 totalReceived;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokenAmounts[i] == 0) continue;
            if (!_checkSwapPath(tokens[i], dstToken, swapPaths[i]))
                revert InvalidSwapPath(swapPaths[i]);
            if (tokens[i] == dstToken) {
                IERC20(tokens[i]).safeTransfer(to, tokenAmounts[i]);
                totalReceived += tokenAmounts[i];
            } else {
                _approveToSwapRouter(tokens[i]);
                totalReceived += IV3SwapRouter(swapRouter).exactInput(
                    IV3SwapRouter.ExactInputParams({
                        path: swapPaths[i],
                        recipient: to,
                        amountIn: tokenAmounts[i],
                        amountOutMinimum: 1
                    })
                );
            }
        }

        if (totalReceived < minDstTokenAmount) revert OverSlippage();

        emit RedeemedToToken(dstToken, to, burnAmount, totalReceived);
    }

    function _approveToSwapRouter(address token) internal {
        if (
            IERC20(token).allowance(address(this), swapRouter) <
            type(uint256).max
        ) {
            IERC20(token).forceApprove(swapRouter, type(uint256).max);
        }
    }

    // The first token in the path must be tokenA, the last token must be tokenB
    function _checkSwapPath(
        address tokenA,
        address tokenB,
        bytes memory path
    ) internal pure returns (bool) {
        (address firstToken, address secondToken, ) = path.decodeFirstPool();
        if (tokenA == tokenB) {
            if (
                firstToken == tokenA &&
                secondToken == tokenA &&
                !path.hasMultiplePools()
            ) {
                return true;
            } else {
                return false;
            }
        } else {
            if (firstToken != tokenA) return false;
            while (path.hasMultiplePools()) {
                path = path.skipToken();
            }
            (, secondToken, ) = path.decodeFirstPool();
            if (secondToken != tokenB) return false;
            return true;
        }
    }

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        if (!success) revert SafeTransferETHFailed();
    }
}
