// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { ICelerMessageBus, ICelerMessageReceiver } from "../common/CelerIM.sol";
import { MessageContext, ExecutionStatus, Spoke } from "../common/Endpoint.sol";
import { UsesCelerIM } from "../common/CelerIM.sol";


event Pong(bytes32 x);

/// Raw implementation of Celer IM interface
contract MockPingPong is ICelerMessageReceiver {

    ICelerMessageBus messageBus;
    address remoteContract;
    uint256 remoteChainId;

    constructor (
        ICelerMessageBus in_messageBus,
        address in_remoteContract,
        uint256 in_remoteChainId
    ) {
        messageBus = in_messageBus;
        remoteContract = in_remoteContract;
        remoteChainId = in_remoteChainId;
    }

    function ping (bytes32 x) external payable {
        bytes memory message = abi.encode(x);
        uint fee = messageBus.calcFee(message);
        messageBus.sendMessage{value:fee}(remoteContract, remoteChainId, message);
        if( msg.value > fee ) {
            payable(msg.sender).transfer(msg.value-fee);
        }
    }

    function pong (bytes32 x) internal returns (uint) {
        emit Pong(x);
        return 1;
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
        require( msg.sender == address(messageBus), "BAD messageBus" );

        require( in_sender == remoteContract, "BAD remoteContract" );

        require( in_senderChainId == remoteChainId, "BAD remoteChainId" );

        require( in_executor == tx.origin, "BAD executor!" );

        return pong(abi.decode(in_message, (bytes32)));
    }
}

/// Direct use of `UsesCelerIM`, implements `_Endpoint_receive`
contract MockPingPongUsingEndpoint is UsesCelerIM {

    address remoteContract;
    uint256 remoteChainId;

    constructor (
        ICelerMessageBus in_messageBus,
        address in_remoteContract,
        uint256 in_remoteChainId
    )
        UsesCelerIM(in_messageBus)
    {
        remoteContract = in_remoteContract;
        remoteChainId = in_remoteChainId;
    }

    function ping (bytes32 x) external payable {
        uint fee = _Endpoint_send(
            MessageContext(remoteContract, remoteChainId, msg.sender),
            abi.encode(x));
        if( msg.value > fee ) {
            payable(msg.sender).transfer(msg.value-fee);
        }
    }

    function pong (bytes32 x) internal returns (ExecutionStatus) {
        emit Pong(x);
        return ExecutionStatus.Success;
    }

    function _Endpoint_receive(MessageContext memory in_ctx, bytes memory in_message)
        internal override
        returns (ExecutionStatus)
    {
        require( in_ctx.remoteContract == remoteContract, "BAD remoteContract" );

        require( in_ctx.remoteChainId == remoteChainId, "BAD remoteChainId" );

        return pong(abi.decode(in_message, (bytes32)));
    }
}

contract MockPingPongUsingSpoke is UsesCelerIM, Spoke {

    constructor (
        ICelerMessageBus in_messageBus,
        address in_remoteContract,
        uint256 in_remoteChainId
    )
        UsesCelerIM(in_messageBus)
        Spoke(in_remoteContract, in_remoteChainId)
    { }

    function ping (bytes32 x) external payable {
        uint fee = _Endpoint_send(
            MessageContext(remoteContract, remoteChainId, msg.sender),
            abi.encode(x));
        if( msg.value > fee ) {
            payable(msg.sender).transfer(msg.value-fee);
        }
    }

    function pong (bytes32 x) internal returns (ExecutionStatus) {
        emit Pong(x);
        return ExecutionStatus.Success;
    }

    function _Spoke_receive(address, bytes memory in_message)
        internal override
        returns (ExecutionStatus)
    {
        return pong(abi.decode(in_message, (bytes32)));
    }
}
