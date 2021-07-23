# Bird Finance Protocol

[![Documentation Status](https://readthedocs.org/projects/bird-finance/badge/?version=latest)](https://bird-finance.readthedocs.io/?badge=latest)

Bird Finance is a niche protocol for [Curve Finance](https://polygon.curve.fi) liquidity providers on the [Polygon Network](https://polygon.technology) to maximize their yield without sacrificing their CRV.

## Overview

Bird Finance was inspired by protocols like [Convex Finance](https://convexfinance.com) and [Yearn Finance](https://yearn.finance) on the [Ethereum Network](https://ethereum.org).
Seeing as there is a void on the Polygon Network for Liquidity Providers of the Curve Protocol, Bird Finance seeks to fill that void.

Similar to [Curve Finance](https://github.com/curvefi), Bird Finance heavily utilizes the Python ecosystem for contract development. Our contracts are written entirely in [Vyper](https://vyperlang.readthedocs.io), and our testing framework of choice is [eth-brownie](https://github.com/eth-brownie/brownie)

## Development

To get started with development you'll need the following installed globally:

- [Python3+](https://www.python.org/)
- [Ganache CLI](https://github.com/trufflesuite/ganache-cli)

As well as the following environment variables:

- [WEB3_INFURA_PROJECT_ID](https://infura.io/): An infura project id
- [POLYGONSCAN_TOKEN](https://polygonscan.com/apis): A polygonscan api key

After which you can setup your development environment simply by running the following command in your shell:

```bash
$ pip install -r requirements-dev.txt
```
