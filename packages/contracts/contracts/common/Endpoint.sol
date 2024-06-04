// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

/// The outcome of the message call.
enum ExecutionStatus {
    Fail,               // 0
    Success,            // 1
    TransientFailure    // 2
}

struct MessageContext {
    address remoteContract;
    uint remoteChainId;
    address localExecutor;
}

struct Message {
    bytes4 selector;
    bytes data;
}

function predictEncodedMessageLength(uint in_messageDataLength)
    pure returns (uint)
{
    return (in_messageDataLength - (in_messageDataLength%32)) + 160;
}

abstract contract MessageReceiver {
    function _receiveMessage(Message memory message, address in_executor)
        internal virtual
        returns (ExecutionStatus);
}

abstract contract MessageEncoder {
    function _encodeMessage(bytes4 in_selector, bytes memory in_data)
        internal virtual
        returns (bytes memory out_encoded);
}

abstract contract _Endpoint {
    function _Endpoint_receive(MessageContext memory in_ctx, bytes memory in_message)
        internal virtual
        returns (ExecutionStatus);

    /// Implemented by underlying bridge
    function _Endpoint_transmissionCost(MessageContext memory in_ctx, uint in_messageLength)
        internal view virtual
        returns (uint);

    /// Implemented by underlying bridge
    function _Endpoint_send(MessageContext memory in_ctx, bytes memory in_message, uint in_fee)
        internal virtual;

    /// Auto-calculates cost before sending, return cost
    function _Endpoint_send(MessageContext memory in_ctx, bytes memory in_message)
        internal
        returns (uint)
    {
        uint fee = _Endpoint_transmissionCost(in_ctx, in_message.length);

        _Endpoint_send(in_ctx, in_message, fee);

        return fee;
    }
}

/// A raw endpoint is also called a hub
abstract contract Hub is _Endpoint {

}

/// Has a fixed remote contract on a specific chain
abstract contract Spoke is _Endpoint
{
    address public immutable remoteContract;

    uint public immutable remoteChainId;

    constructor (address in_remoteContract, uint in_remoteChainId)
    {
        remoteContract = in_remoteContract;

        remoteChainId = in_remoteChainId;
    }

    function _Endpoint_receive(MessageContext memory ctx, bytes memory message)
        internal override
        returns (ExecutionStatus)
    {
        require( ctx.remoteContract == remoteContract );

        require( ctx.remoteChainId == remoteChainId );

        return _Spoke_receive(ctx.localExecutor, message);
    }

    /// Implemented by inheriting contract
    function _Spoke_receive(address in_executor, bytes memory in_message)
        internal virtual
        returns (ExecutionStatus);

    function _Spoke_transmissionContext()
        internal view
        returns (MessageContext memory)
    {
        return MessageContext(remoteContract, remoteChainId, msg.sender);
    }

    /// Used by inheriting contract
    function _Spoke_transmissionCost(uint in_messageLength)
        internal view
        returns (uint)
    {
        return _Endpoint_transmissionCost(_Spoke_transmissionContext(), in_messageLength);
    }

    function _Spoke_send(bytes memory in_message)
        internal
        returns (uint)
    {
        return _Endpoint_send(_Spoke_transmissionContext(), in_message);
    }

    function _Spoke_send(bytes memory in_message, uint in_fee)
        internal
    {
        return _Endpoint_send(_Spoke_transmissionContext(), in_message, in_fee);
    }
}
