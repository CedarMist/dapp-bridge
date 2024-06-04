// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { SignatureRSV } from "@oasisprotocol/sapphire-contracts/contracts/EthereumUtils.sol";

// Pack yParity(v) & S into `vs` according to https://eips.ethereum.org/EIPS/eip-2098
function eip2098_encode(SignatureRSV memory x)
    pure
    returns (bytes32[2] memory)
{
    uint yParity = x.v;
    if( (yParity & 1) != yParity ) {
     yParity = yParity == 27 ? 0 : 1;
    }
    return [
        x.r,
        bytes32((yParity << 255) | uint(x.s))
    ];
}

function eip2098_decode(bytes32[2] memory rvs)
    pure
    returns (SignatureRSV memory x)
{
    x.r = rvs[0];

    x.v = uint(rvs[1]) >> 255;

    x.s = bytes32((uint(rvs[1]) << 1) >> 1);
}
