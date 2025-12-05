// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ETFv1} from "../src/etf/ETFv1.sol";

contract ETFv1Script is Script {
    string name;
    string symbol;
    address[] tokens;
    uint256[] initTokenAmountPerShares;
    uint256 minMintAmount;

    address feeTo;
    uint24 investFee;
    uint24 redeemFee;

    function setUp() public {
        name = "SimpleETF";
        symbol = "sETF";

        address wbtc = 0x2e67186298e9B87D6822f02F103B11F5cb5e450C;
        address weth = 0x51C6De85b859D24c705AbC4d1fdCc3eD613b203c;
        address link = 0x7826216Cd2917f12B67880Ef513e6cDAa09dC042;
        address aud = 0xbbdb08AdB8Dc86B3D02860eD281139CD6Be453A5;
        tokens = [wbtc, weth, link, aud];

        // btc 77000, eth 3100, link 14, aud 0.6
        // weights: btc 40%, eth 30%, link 20%, aud 10%
        // 1 Share = 100U
        // btcAmountPerShare = 100 * 40% / 77000 * 1e8 = 51,948
        // ethAmountPerShare = 100 * 30% / 3100 * 1e18 = 9,677,419,354,838,710
        // linkAmountPerShare = 100 * 20% / 14 * 1e18 = 1,428,571,428,571,428,600
        // audAmountPerShare = 100 * 10% / 0.6 * 1e18 = 16,666,666,666,666,668,000
        initTokenAmountPerShares = [
            51948,
            9677419354838710,
            1428571428571428600,
            16666666666666668000
        ];

        minMintAmount = 1e18;

        feeTo = 0x1956b2c4C511FDDd9443f50b36C4597D10cD9985;
        investFee = 1000; // 0.1%
        redeemFee = 1000; // 0.1%
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ETFv1 etf = new ETFv1(
            name,
            symbol,
            tokens,
            initTokenAmountPerShares,
            minMintAmount
        );
        console.log("ETFv1:", address(etf));

        etf.setFee(feeTo, investFee, redeemFee);

        vm.stopBroadcast();
    }
}
