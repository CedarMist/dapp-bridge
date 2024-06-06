// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { ExecutionStatus, Spoke, MessageContext } from "./Endpoint.sol";
import { IMessageReceiver, IMessageEncoder, IMessageDecoder, Message,
         IMessageSender, predictEncodedMessageLength, encodedBytesLength,
         decodeMessage, encodeMessage } from "./Message.sol";
import { EthereumUtils, SignatureRSV } from "@oasisprotocol/sapphire-contracts/contracts/EthereumUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { eip2098_encode } from "../lib/eip2098.sol";

abstract contract SignedDecoder {

    address public immutable remoteSigner;

    constructor (address in_remoteSigner) {
        remoteSigner = in_remoteSigner;
    }

    function _decodeSigned(bytes memory in_data)
        internal view
        returns (bytes memory out_data)
    {
        bytes32[2] memory sig;

        (sig, out_data) = abi.decode(in_data, (bytes32[2], bytes));

        bytes32 digest = keccak256(out_data);

        address signer = ECDSA.recover(digest, sig[0], sig[1]);

        require( signer == remoteSigner, "signature verification failed" );
    }
}

abstract contract SignedEncoder {

    bytes32 private immutable signingSecret;

    address public immutable signingPublic;

    constructor ()
    {
        (signingPublic, signingSecret) = EthereumUtils.generateKeypair();
    }

    function _sign(bytes memory in_data)
        internal view
        returns (bytes32[2] memory sig)
    {
        return eip2098_encode(
                EthereumUtils.sign(
                    signingPublic,
                    signingSecret,
                    keccak256(in_data)));
    }

    /// Predict length of signature-prefixed bytes
    function _predictSignedEncodedLength(uint in_bytesLength)
        internal pure
        returns (uint)
    {
        return encodedBytesLength(in_bytesLength) + 64;
    }

    /// Prepend EIP-2098 encoded signature to bytes
    function _encodeSigned(bytes memory in_bytes)
        internal view
        returns (bytes memory out)
    {
        return abi.encode(_sign(in_bytes), in_bytes);
    }
}

/// Prefix all messages with a unique tag (message ID)
abstract contract UniqueEncoder {

    bytes32 private messageId;

    constructor () {
        _cycleMessageId();
    }

    function _cycleMessageId()
        internal
        returns (bytes32)
    {
        return messageId = keccak256(
            abi.encodePacked(
                address(this),
                block.timestamp,
                block.chainid,
                msg.sender,
                tx.origin,
                messageId));
    }

    /// Predict tag-prefixed message length after encoding
    function _predictUniqueEncodedLength(uint in_bytesLength)
        internal pure
        returns (uint)
    {
        return 32 + encodedBytesLength(in_bytesLength);
    }

    function _encodeUnique(bytes memory in_message)
        internal
        returns (bytes memory)
    {
        return abi.encode(_cycleMessageId(), in_message);
    }
}

/**
 * Each received message must be accompanied by a unique ID to prevent replays.
 *
 * This will refuse to decode the same message twice.
 *
 * It is independent of any replay protection provided by the underlying
 *  message passing bridge.
 */
abstract contract UniqueDecoder {

    mapping( bytes32 => bool ) public messageIds;

    function _decodeUnique(bytes memory in_data)
        internal
        returns (bytes memory output)
    {
        bytes32 messageId;

        (messageId, output) = abi.decode(in_data, (bytes32,bytes));

        require( messageIds[messageId] == false, "duplicate message" );

        messageIds[messageId] = true;
    }
}

abstract contract SignedUniqueDecoder is SignedDecoder, UniqueDecoder
{
    constructor (address in_remoteSigner)
        SignedDecoder(in_remoteSigner)
    { }

    function _decodeSignedUnique(bytes memory in_data)
        internal
        returns (bytes memory)
    {
        return _decodeUnique(_decodeSigned(in_data));
    }
}

abstract contract SignedUniqueSender is SignedEncoder, UniqueEncoder
{
    constructor ()
        SignedEncoder()
        UniqueEncoder()
    { }

    function _predictSignedUniqueEncodedLength(uint in_bytesLength)
        internal pure
        returns (uint)
    {
        return _predictSignedEncodedLength(_predictUniqueEncodedLength(in_bytesLength));
    }

    function _encodeSignedUnique(bytes memory in_data)
        internal
        returns (bytes memory)
    {
        return _encodeSigned(_encodeUnique(in_data));
    }
}

abstract contract UniqueMessageDecoder is UniqueDecoder, IMessageDecoder {
    constructor ()
        UniqueDecoder()
    { }

    function _decodeMessage(bytes memory in_data)
        internal override
        returns (Message memory)
    {
        return decodeMessage(_decodeUnique(in_data));
    }
}

abstract contract UniqueMessageEncoder is UniqueEncoder, IMessageEncoder {
    constructor ()
    { }

    function _encodedMessageLength(uint in_dataLength)
        internal pure override
        returns (uint)
    {
        return _predictUniqueEncodedLength(predictEncodedMessageLength(in_dataLength));
    }

    function _encodeMessage(bytes4 in_selector, bytes memory in_data)
        internal override
        returns (bytes memory out_encoded)
    {
        return _encodeUnique(encodeMessage(in_selector, in_data));
    }
}

abstract contract SignedUniqueMessageDecoder is SignedUniqueDecoder, IMessageDecoder
{
    constructor (address in_remoteSigner)
        SignedUniqueDecoder(in_remoteSigner)
    { }

    function _decodeMessage(bytes memory in_data)
        internal override
        returns (Message memory)
    {
        return decodeMessage(_decodeSignedUnique(in_data));
    }
}

abstract contract SignedUniqueMessageEncoder is SignedUniqueSender, IMessageEncoder
{
    constructor ()
        SignedUniqueSender()
    { }

    function _encodedMessageLength(uint in_messageDataLength)
        internal pure override
        returns (uint)
    {
        return _predictSignedUniqueEncodedLength(
            predictEncodedMessageLength(in_messageDataLength));
    }

    function _encodeMessage(bytes4 in_selector, bytes memory in_data)
        internal override
        returns (bytes memory)
    {
        return _encodeSignedUnique(encodeMessage(in_selector, in_data));
    }
}
