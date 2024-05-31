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
    function _encodeMessage(Message memory message)
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

abstract contract _HomoEndpoint is _Endpoint
{
    function _HomoEndpoint_context(uint in_remoteChainId)
        internal view
        returns (MessageContext memory)
    {
        return MessageContext(address(this), in_remoteChainId, msg.sender);
    }

    function _Endpoint_receive(MessageContext memory in_ctx, bytes memory in_message)
        internal override
        returns (ExecutionStatus)
    {
        require( in_ctx.remoteContract == address(this) );

        return _HomoEndpoint_receive(in_ctx.remoteChainId, in_ctx.localExecutor, in_message);
    }

    /// Implemented by inheriting contract
    function _HomoEndpoint_receive(uint in_remoteChainId, address in_executor, bytes memory in_message)
        internal virtual
        returns (ExecutionStatus);
}

/// remoteContract is implicitly address(this)
abstract contract HomoHub is _HomoEndpoint
{
    /// Implemented by inheriting contract
    function _HomoHub_receive(uint in_remoteChainId, address in_executor, bytes memory in_message)
        internal virtual
        returns (ExecutionStatus);

    function _HomoEndpoint_receive(uint in_remoteChainId, address in_executor, bytes memory in_message)
        internal override
        returns (ExecutionStatus)
    {
        return _HomoHub_receive(in_remoteChainId, in_executor, in_message);
    }

    function _HomoHub_transmissionCost(uint in_remoteChainId, uint in_messageLength)
        internal view
        returns (uint)
    {
        return _Endpoint_transmissionCost(_HomoEndpoint_context(in_remoteChainId), in_messageLength);
    }

    function _HomoHub_send(uint in_remoteChainId, bytes memory in_message, uint in_fee)
        internal
    {
        return _Endpoint_send(_HomoEndpoint_context(in_remoteChainId), in_message, in_fee);
    }

    function _HomoHub_send(uint in_remoteChainId, bytes memory in_message)
        internal
    {
        MessageContext memory ctx = _HomoEndpoint_context(in_remoteChainId);

        return _Endpoint_send(ctx, in_message, _Endpoint_transmissionCost(ctx, in_message.length));
    }
}

/// remoteContract is implicitly address(this)
abstract contract HomoSpoke is _HomoEndpoint
{
    uint public immutable remoteChainId;

    constructor (uint in_remoteChainId)
    {
        remoteChainId = in_remoteChainId;
    }

    function _HomoSpoke_send(bytes memory in_message)
        internal
    {
        _Endpoint_send(_HomoEndpoint_context(remoteChainId), in_message);
    }

    function _HomoSpoke_transmissionCost(uint in_messageLength)
        internal view
        returns (uint)
    {
        return _Endpoint_transmissionCost(_HomoEndpoint_context(remoteChainId), in_messageLength);
    }

    function _HomoEndpoint_receive(uint in_remoteChainId, address in_executor, bytes memory in_message)
        internal override
        returns (ExecutionStatus)
    {
        require( in_remoteChainId == remoteChainId );

        return _HomoSpoke_receive(in_executor, in_message);
    }

    function _HomoSpoke_receive(address in_executor, bytes memory in_message)
        internal virtual
        returns (ExecutionStatus);
}
