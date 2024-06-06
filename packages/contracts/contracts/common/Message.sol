// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { ExecutionStatus, Spoke } from "./Endpoint.sol";

struct Message {
    bytes4 selector;
    bytes data;
}

/**
 * Predict the abi.encode() length of `bytes memory`
 * @param in_bytesLength `data.length` of `bytes memory data`
 */
function encodedBytesLength(uint in_bytesLength)
    pure
    returns (uint out_length)
{
    out_length = 64;

    if( in_bytesLength > 0 )
    {
        if( in_bytesLength % 32 != 0 )
        {
            out_length += 32;
        }
        out_length += in_bytesLength - (in_bytesLength % 32);
    }
}

function encodeMessage(bytes4 in_selector, bytes memory in_data)
    pure
    returns (bytes memory)
{
    return abi.encode(Message(in_selector, in_data));
}

function decodeMessage(bytes memory in_data)
    pure
    returns (Message memory)
{
    return abi.decode(in_data, (Message));
}

/**
 * Predict the `abi.encode()` size of an encoded `Message` struct
 * @param in_dataLength Message.data.length
 */
function predictEncodedMessageLength(uint in_dataLength)
    pure returns (uint)
{
    return encodedBytesLength(in_dataLength) + 64;
}

abstract contract IMessageReceiver {
    function _receiveMessage(Message memory message, address in_executor)
        internal virtual
        returns (ExecutionStatus);
}

abstract contract IMessageDecoder {
    function _decodeMessage(bytes memory in_data)
        internal virtual
        returns (Message memory out_msg);
}

abstract contract IMessageEncoder {
    /**
     * Predict the length of an encoded message, used to determine the
     * transmission cost before sending it.
     *
     * @param in_dataLength Length of message data
     */
    function _encodedMessageLength(uint in_dataLength)
        internal view virtual
        returns (uint);

    function _encodeMessage(bytes4 in_selector, bytes memory in_data)
        internal virtual
        returns (bytes memory out_encoded);
}

abstract contract IMessageSender {
    function _sendMessage(bytes4 in_selector, bytes memory in_data)
        internal virtual
        returns (uint out_fee);

    function _sendMessage(bytes4 in_selector, bytes memory in_data, uint in_fee)
        internal virtual;
}


abstract contract SpokeMessenger is Spoke, IMessageEncoder, IMessageDecoder, IMessageReceiver, IMessageSender
{
    constructor (address in_remoteAddress, uint in_remoteChainId)
        Spoke(in_remoteAddress, in_remoteChainId)
    { }

    function _transmissionCost(uint in_dataLength)
        internal view
        returns (uint)
    {
        return _Spoke_transmissionCost(_encodedMessageLength(in_dataLength));
    }

    function _sendMessage(bytes4 in_selector, bytes memory in_data)
        internal override
        returns (uint out_fee)
    {
        return _Spoke_send(_encodeMessage(in_selector, in_data));
    }

    function _sendMessage(bytes4 in_selector, bytes memory in_data, uint in_fee)
        internal override
    {
        return _Spoke_send(_encodeMessage(in_selector, in_data), in_fee);
    }

    function _Spoke_receive(address in_executor, bytes memory in_data)
        internal override
        returns (ExecutionStatus)
    {
        return _receiveMessage(_decodeMessage(in_data), in_executor);
    }
}
