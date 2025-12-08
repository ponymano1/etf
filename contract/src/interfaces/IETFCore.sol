// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IETFCore {
    error LessThanMinMintAmount();
    error TokenNotFound();
    error TokenExists();

    event Invested(
        address to,
        uint256 mintAmount,
        uint256 investFee,
        uint256[] tokenAmounts
    );
    event Redeemed(
        address sender,
        address to,
        uint256 burnAmount,
        uint256 redeemFee,
        uint256[] tokenAmounts
    );
    event MinMintAmountUpdated(
        uint256 oldMinMintAmount,
        uint256 newMinMintAmount
    );
    event TokenAdded(address token, uint256 index);
    event TokenRemoved(address token, uint256 index);

    function setFee(
        address feeTo_,
        uint24 investFee_,
        uint24 redeemFee_
    ) external;

    function updateMinMintAmount(uint256 newMinMintAmount) external;

    /**
     * 铸造份额给用户
     * 转移token到合约
     * 注意：invest with all tokens, msg.sender need have approved all tokens to this contract
     * @param to
     * @param mintAmount
     */
    function invest(address to, uint256 mintAmount) external;

    function redeem(address to, uint256 burnAmount) external;

    function feeTo() external view returns (address);

    function investFee() external view returns (uint24);

    function redeemFee() external view returns (uint24);

    function minMintAmount() external view returns (uint256 minMintAmount);

    function getTokens() external view returns (address[] memory);

    function getInitTokenAmountPerShares()
        external
        view
        returns (uint256[] memory);

    function getInvestTokenAmounts(
        uint256 mintAmount
    ) external view returns (uint256[] memory tokenAmounts);

    function getRedeemTokenAmounts(
        uint256 burnAmount
    ) external view returns (uint256[] memory tokenAmounts);
}
