// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {SignatureRSV} from "@oasisprotocol/sapphire-contracts/contracts/EthereumUtils.sol";

// Pack yParity(v) & S into `vs` according to https://eips.ethereum.org/EIPS/eip-2098
function eip2098(SignatureRSV memory x) pure returns (bytes32[2] memory) {
    return [x.r, bytes32((x.v << 255) | uint(x.s))];
}

