// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { SignedUniqueMessageDecoder, SignedUniqueMessageEncoder,
         UniqueMessageEncoder, UniqueMessageDecoder, Message } from "../common/SignedUniqueMessage.sol";

event OutputData(bytes data, uint predictedLength);
event OutputMessage(Message message);

contract TestEncoders is SignedUniqueMessageEncoder {
    constructor ()
        SignedUniqueMessageEncoder()
    { }

    function testUnique(bytes memory in_data)
        external
        returns (bytes memory out_data, uint out_predictedLength)
    {
        out_data = _encodeUnique(in_data);

        out_predictedLength = _predictUniqueEncodedLength(in_data.length);

        emit OutputData(out_data, out_predictedLength);
    }

    function testSigned(bytes memory in_data)
        external
        returns (bytes memory out_data, uint out_predictedLength)
    {
        out_data = _encodeSigned(in_data);

        out_predictedLength = _predictSignedEncodedLength(in_data.length);

        emit OutputData(out_data, out_predictedLength);
    }

    function testSignedUnique(bytes memory in_data)
        external
        returns (bytes memory out_data, uint out_predictedLength)
    {
        out_data = _encodeSignedUnique(in_data);

        out_predictedLength = _predictSignedUniqueEncodedLength(in_data.length);

        emit OutputData(out_data, out_predictedLength);
    }

    function testSignedUniqueMessage(bytes4 in_selector, bytes memory in_data)
        external
        returns (bytes memory out_data, uint out_predictedLength)
    {
        out_data = _encodeMessage(in_selector, in_data);

        out_predictedLength = _encodedMessageLength(in_data.length);

        emit OutputData(out_data, out_predictedLength);
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

        emit OutputData(out_data, out_data.length);
    }

    function testSigned(bytes memory in_data)
        external
        returns (bytes memory out_data)
    {
        out_data = _decodeSigned(in_data);

        emit OutputData(out_data, out_data.length);
    }

    function testSignedUnique(bytes memory in_data)
        external
        returns (bytes memory out_data)
    {
        out_data = _decodeSignedUnique(in_data);

        emit OutputData(out_data, out_data.length);
    }

    function testSignedUniqueMessage(bytes memory in_data)
        external
        returns (Message memory out_message)
    {
        out_message = _decodeMessage(in_data);

        emit OutputMessage(out_message);
    }
}

contract TestUniqueMessageEncoder is UniqueMessageEncoder {
    function testUniqueMessage(bytes4 in_selector, bytes memory in_data)
        external
        returns (bytes memory out_data, uint out_predictedLength)
    {
        out_data = _encodeMessage(in_selector, in_data);

        out_predictedLength = _encodedMessageLength(in_data.length);

        emit OutputData(out_data, out_predictedLength);
    }
}

contract TestUniqueMessageDecoder is UniqueMessageDecoder {
    function testUniqueMessage(bytes memory in_data)
        external
        returns (Message memory out_message)
    {
        out_message = _decodeMessage(in_data);

        emit OutputMessage(out_message);
    }
}
