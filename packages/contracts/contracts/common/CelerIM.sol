// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { _Endpoint, MessageContext } from "./Endpoint.sol";

interface ICelerMessageBus {
    function feeBase() external view returns (uint256);

    function feePerByte() external view returns (uint256);

    function calcFee(bytes calldata _message) external view returns (uint256);

    function sendMessage(
        address in_remoteContract,
        uint256 in_remoteChainId,
        bytes calldata in_message
    ) external payable;
}

interface ICelerMessageReceiver {
    function executeMessage(
        address in_sender,
        uint64 in_senderChainId,
        bytes calldata in_message,
        address in_executor
    )
        external payable
        returns (uint256);
}

abstract contract UsesCelerIM is _Endpoint, ICelerMessageReceiver
{
    ICelerMessageBus internal _celer_messageBus;

    constructor (ICelerMessageBus in_msgbus)
    {
        _celer_messageBus = in_msgbus;
    }

    function _Endpoint_transmissionCost(MessageContext memory, uint in_messageLength)
        internal view override
        returns (uint256)
    {
        uint256 feeBase = ICelerMessageBus(_celer_messageBus).feeBase();

        uint256 feePerByte = ICelerMessageBus(_celer_messageBus).feePerByte();

        return feeBase + (in_messageLength * feePerByte);
    }

    function _Endpoint_send(
        MessageContext memory in_ctx, bytes memory in_message, uint in_fee
    )
        internal override
    {
        _celer_messageBus.sendMessage{value: in_fee}(
            in_ctx.remoteContract,
            in_ctx.remoteChainId,
            in_message
        );
    }

    function executeMessage(
        address in_sender,
        uint64 in_senderChainId,
        bytes calldata in_message,
        address in_executor
    )
        external payable
        returns (uint256)
    {
        require( msg.sender == address(_celer_messageBus) );

        return uint(_Endpoint_receive(
            MessageContext({
                remoteContract: in_sender,
                remoteChainId: in_senderChainId,
                localExecutor: in_executor
            }),
            in_message));
    }
}
