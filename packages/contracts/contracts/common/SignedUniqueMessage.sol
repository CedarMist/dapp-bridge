// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { ExecutionStatus, Spoke, MessageContext, MessageReceiver,
         MessageEncoder, Message, predictEncodedMessageLength } from "./Endpoint.sol";
import { EthereumUtils, SignatureRSV } from "@oasisprotocol/sapphire-contracts/contracts/EthereumUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { eip2098 } from "../lib/eip2098.sol";

struct SignedMessageEnvelope {
    bytes32[2] sig;
    bytes envelope;
}

abstract contract SignedReceiver {

    address public immutable remoteSigner;

    constructor (address in_remoteSigner) {
        remoteSigner = in_remoteSigner;
    }

    function _decodeSigned(bytes memory in_message)
        internal view
        returns (bytes memory)
    {
        SignedMessageEnvelope memory signedEnvelope = abi.decode(in_message, (SignedMessageEnvelope));

        bytes32 digest = keccak256(signedEnvelope.envelope);

        address signer = ECDSA.recover(digest, signedEnvelope.sig[0], signedEnvelope.sig[1]);

        require( signer == remoteSigner );

        return signedEnvelope.envelope;
    }
}

abstract contract SignedSender {

    bytes32 private signingSecret;

    address public signingPublic;

    constructor ()
    {
        (signingPublic, signingSecret) = EthereumUtils.generateKeypair();
    }

    function _signMessage(bytes memory in_message)
        internal view
        returns (SignedMessageEnvelope memory out)
    {
        out.envelope = in_message;
        out.sig = eip2098(
                EthereumUtils.sign(
                    signingPublic,
                    signingSecret,
                    keccak256(in_message)));
    }

    /// Predict length of signature-prefixed bytes
    function _predictSignedEncodedLength(uint in_bytesLength)
        internal pure
        returns (uint)
    {
        return (in_bytesLength - (in_bytesLength%32)) + 160;
    }

    /// Prepend EIP-2098 encoded signature to bytes
    function _encodeSigned(bytes memory in_bytes)
        internal view
        returns (bytes memory out)
    {
        return abi.encode(_signMessage(in_bytes), in_bytes);
    }
}

/// Prefix all messages with a unique tag (message ID)
abstract contract UniqueSender {

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
        return (in_bytesLength - (in_bytesLength%32)) + 128;
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
abstract contract UniqueReceiver {

    mapping( bytes32 => bool ) public messageIds;

    function _decodeUnique(bytes memory in_data)
        internal
        returns (bytes memory output)
    {
        bytes32 mid;

        (mid,output) = abi.decode(in_data, (bytes32,bytes));

        require( messageIds[mid] == false );

        messageIds[mid] = true;
    }
}

abstract contract SignedUniqueMessageDecoder is SignedReceiver, UniqueReceiver
{
    constructor (address in_remoteSigner)
        SignedReceiver(in_remoteSigner)
    { }

    function _decodeSignedUniqueMessage(bytes memory in_message)
        internal
        returns (Message memory)
    {
        return abi.decode(_decodeSigned(_decodeUnique(in_message)), (Message));
    }
}

abstract contract SignedUniqueMessageEncoder is SignedSender, UniqueSender
{
    constructor ()
        SignedSender()
        UniqueSender()
    { }

    function _predictSignedUniqueEncodedLength(uint in_bytesLength)
        internal pure
        returns (uint)
    {
        return _predictSignedEncodedLength(_predictUniqueEncodedLength(in_bytesLength));
    }

    function _encodeUniqueSignedMessage(bytes memory in_message)
        internal
        returns (bytes memory)
    {
        return _encodeSigned(_encodeUnique(in_message));
    }
}

abstract contract SpokeSUMSender is SignedUniqueMessageEncoder, Spoke, MessageEncoder
{
    constructor (
        address in_remoteContract,
        uint in_remoteChainId
    )
        SignedUniqueMessageEncoder()
        Spoke(in_remoteContract, in_remoteChainId)
    { }

    function _transmissionCost(uint in_messageDataLength)
        internal view
        returns (uint)
    {
        return _Spoke_transmissionCost(
            _predictSignedUniqueEncodedLength(
                predictEncodedMessageLength(in_messageDataLength)));
    }

    function _sendMessage(bytes4 in_selector, bytes memory in_data, uint in_fee)
        internal
    {
        _Spoke_send(_encodeMessage(Message(in_selector, in_data)), in_fee);
    }

    function _encodeMessage(Message memory message)
        internal override
        returns (bytes memory)
    {
        return _encodeUniqueSignedMessage(abi.encode(message));
    }
}

abstract contract SpokeSUMReceiver is SignedUniqueMessageDecoder, Spoke, MessageReceiver {
    constructor (
        address in_remoteContract,
        uint in_remoteChainId,
        address in_remoteSigner
    )
        SignedUniqueMessageDecoder(in_remoteSigner)
        Spoke(in_remoteContract, in_remoteChainId)
    { }

    function _Spoke_receive(address in_executor, bytes memory in_message)
        internal override
        returns (ExecutionStatus)
    {
        return _receiveMessage(_decodeSignedUniqueMessage(in_message), in_executor);
    }
}

abstract contract SpokeSUMReceiver_UniqueMessageSender is SpokeSUMReceiver, UniqueSender, MessageEncoder {
    constructor (
        address in_remoteContract,
        uint in_remoteChainId,
        address in_remoteSigner
    )
        SpokeSUMReceiver(in_remoteContract, in_remoteChainId, in_remoteSigner)
    { }

    function _encodeMessage(Message memory message)
        internal override
        returns (bytes memory)
    {
        return _encodeUnique(abi.encode(message));
    }

    function _sendMessage(bytes4 in_selector, bytes memory in_data)
        internal
        returns (uint out_fee)
    {
        out_fee = _Spoke_send(_encodeMessage(Message(in_selector, in_data)));
    }

    function _transmissionCost(uint in_messageDataLength)
        internal view
        returns (uint)
    {
        return _Spoke_transmissionCost(
            _predictUniqueEncodedLength(
                predictEncodedMessageLength(in_messageDataLength)));
    }
}

/// A poke that sends signed unique messages, receives unique messages
abstract contract SpokeSUMSender_UniqueMessageReceiver is SpokeSUMSender, UniqueReceiver, MessageReceiver
{
    constructor (
        address in_remoteContract,
        uint in_remoteChainId
    )
        SpokeSUMSender(in_remoteContract, in_remoteChainId)
    { }

    function _Spoke_receive(address in_executor, bytes memory in_message)
        internal override
        returns (ExecutionStatus)
    {
        return _receiveMessage(abi.decode(in_message, (Message)), in_executor);
    }
}
