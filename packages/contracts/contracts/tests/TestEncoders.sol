// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { SignedUniqueMessageDecoder, SignedUniqueMessageEncoder, Message } from "../common/SignedUniqueMessage.sol";

event OutputData(bytes data);
event OutputMessage(Message message);

contract TestEncoders is SignedUniqueMessageEncoder {
    constructor ()
        SignedUniqueMessageEncoder()
    { }

    function testUnique(bytes memory in_data)
        external
        returns (bytes memory out_data)
    {
        out_data = _encodeUnique(in_data);

        emit OutputData(out_data);
    }

    function testSigned(bytes memory in_data)
        external
        returns (bytes memory out_data)
    {
        out_data = _encodeSigned(in_data);

        emit OutputData(out_data);
    }

    function testSignedUnique(bytes memory in_data)
        external
        returns (bytes memory out_data)
    {
        out_data = _encodeSignedUnique(in_data);

        emit OutputData(out_data);
    }

    function testSignedUniqueMessage(bytes4 in_selector, bytes memory in_data)
        external
        returns (bytes memory out_data)
    {
        out_data = _encodeSignedUniqueMessage(in_selector, in_data);

        emit OutputData(out_data);
    }
}

contract TestDecoders is SignedUniqueMessageDecoder {
    constructor (address in_signingPublic)
        SignedUniqueMessageDecoder(in_signingPublic)
    { }

    function testUnique(bytes memory in_data)
        external
        returns (bytes memory out_data)
    {
        out_data = _decodeUnique(in_data);

        emit OutputData(out_data);
    }

    function testSigned(bytes memory in_data)
        external
        returns (bytes memory out_data)
    {
        out_data = _decodeSigned(in_data);

        emit OutputData(out_data);
    }

    function testSignedUnique(bytes memory in_data)
        external
        returns (bytes memory out_data)
    {
        out_data = _decodeSignedUnique(in_data);

        emit OutputData(out_data);
    }

    function testSignedUniqueMessage(bytes memory in_data)
        external
        returns (Message memory out_message)
    {
        out_message = _decodeSignedUniqueMessage(in_data);

        emit OutputMessage(out_message);
    }
}
