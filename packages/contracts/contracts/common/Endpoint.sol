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

abstract contract _Endpoint {
    function _Endpoint_receive(MessageContext memory in_ctx, bytes memory in_data)
        internal virtual
        returns (ExecutionStatus);

    /// Implemented by underlying bridge
    function _Endpoint_transmissionCost(MessageContext memory in_ctx, uint in_dataLength)
        internal view virtual
        returns (uint);

    /// Implemented by underlying bridge
    function _Endpoint_send(MessageContext memory in_ctx, bytes memory in_data, uint in_fee)
        internal virtual;

    /// Auto-calculates cost before sending, return cost
    function _Endpoint_send(MessageContext memory in_ctx, bytes memory in_data)
        internal
        returns (uint)
    {
        uint fee = _Endpoint_transmissionCost(in_ctx, in_data.length);

        _Endpoint_send(in_ctx, in_data, fee);

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

    function _Endpoint_receive(MessageContext memory in_ctx, bytes memory in_data)
        internal override
        returns (ExecutionStatus)
    {
        require( in_ctx.remoteContract == remoteContract );

        require( in_ctx.remoteChainId == remoteChainId );

        return _Spoke_receive(in_ctx.localExecutor, in_data);
    }

    /// Implemented by inheriting contract
    function _Spoke_receive(address in_executor, bytes memory in_data)
        internal virtual
        returns (ExecutionStatus);

    function _Spoke_transmissionContext()
        internal view
        returns (MessageContext memory)
    {
        return MessageContext(remoteContract, remoteChainId, msg.sender);
    }

    /// Used by inheriting contract
    function _Spoke_transmissionCost(uint in_dataLength)
        internal view
        returns (uint)
    {
        return _Endpoint_transmissionCost(_Spoke_transmissionContext(), in_dataLength);
    }

    function _Spoke_send(bytes memory in_data)
        internal
        returns (uint)
    {
        return _Endpoint_send(_Spoke_transmissionContext(), in_data);
    }

    function _Spoke_send(bytes memory in_data, uint in_fee)
        internal
    {
        return _Endpoint_send(_Spoke_transmissionContext(), in_data, in_fee);
    }
}
