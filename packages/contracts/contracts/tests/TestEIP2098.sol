// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { eip2098_encode, eip2098_decode } from "../lib/eip2098.sol";
import { SignatureRSV, EthereumUtils } from "@oasisprotocol/sapphire-contracts/contracts/EthereumUtils.sol";
import { Sapphire } from "@oasisprotocol/sapphire-contracts/contracts/Sapphire.sol";

function generateKeypair(bytes32 secretKey) view returns (address pubkeyAddr)
{
    (bytes memory pk, ) = Sapphire.generateSigningKeyPair(
        Sapphire.SigningAlg.Secp256k1PrehashedKeccak256,
        abi.encodePacked(secretKey)
    );

    pubkeyAddr = EthereumUtils.k256PubkeyToEthereumAddress(pk);
}

contract TestEIP2098 {
    function encode_decode (SignatureRSV memory x)
        external pure
        returns (SignatureRSV memory)
    {
        return eip2098_decode(eip2098_encode(x));
    }

    function sign_encode_decode (bytes32 in_secret, bytes32 in_digest)
        external view
        returns (
            address out_address,
            bytes32[2] memory out_encoded,
            SignatureRSV memory out_sig,
            SignatureRSV memory out_decoded
    ) {
        out_address = generateKeypair(in_secret);

        out_sig = EthereumUtils.sign(out_address, in_secret, in_digest);

        out_encoded = eip2098_encode(out_sig);

        out_decoded = eip2098_decode(out_encoded);
    }
}
