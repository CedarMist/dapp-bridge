// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { UsesCelerIM } from "../common/CelerIM.sol";
import { Message, SpokeMessenger } from "../common/Message.sol";
import { MessageContext, ExecutionStatus, Spoke } from "../common/Endpoint.sol";
import { ICelerMessageBus, ICelerMessageReceiver } from "../common/CelerIM.sol";
import { SignedUniqueMessageEncoder, SignedUniqueMessageDecoder,
         UniqueMessageEncoder, UniqueMessageDecoder } from "../common/SignedUniqueMessage.sol";

event Pong(bytes32 x);

/// Raw implementation of Celer IM interface
contract MockPingPong is ICelerMessageReceiver {

    ICelerMessageBus public immutable _celer_messageBus;
    address public immutable remoteContract;
    uint256 public immutable remoteChainId;

    constructor (
        ICelerMessageBus in_messageBus,
        address in_remoteContract,
        uint256 in_remoteChainId
    ) {
        _celer_messageBus = in_messageBus;
        remoteContract = in_remoteContract;
        remoteChainId = in_remoteChainId;
    }

    function pingCost () external view returns (uint) {
        return _celer_messageBus.calcFee(pingMessage(0));
    }

    function pingMessageLength () external pure returns (uint) {
        return 32;
    }

    function pingMessage (bytes32 x) public pure returns (bytes memory) {
        return abi.encode(x);
    }

    function ping (bytes32 x) external payable {
        bytes memory message = pingMessage(x);
        uint fee = _celer_messageBus.calcFee(message);
        _celer_messageBus.sendMessage{value:fee}(remoteContract, remoteChainId, message);
        require( msg.value == fee, "BAD FEE!" );
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
        require( msg.sender == address(_celer_messageBus), "BAD messageBus" );

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

    function pingCost () external view returns (uint) {
        return _Endpoint_transmissionCost(
            MessageContext(remoteContract, remoteChainId, msg.sender),
            pingMessage(0).length);
    }

    function pingMessageLength () external pure returns (uint) {
        return 32;
    }

    function pingMessage (bytes32 x) public pure returns (bytes memory) {
        return abi.encode(x);
    }

    function ping (bytes32 x) external payable {
        uint fee = _Endpoint_send(
            MessageContext(remoteContract, remoteChainId, msg.sender),
            pingMessage(x));
        require( msg.value == fee, "BAD FEE!" );
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

/// Combines `UsesCelerIM` with `Spoke` for further simplification
contract MockPingPongUsingSpoke is UsesCelerIM, Spoke {

    constructor (
        ICelerMessageBus in_messageBus,
        address in_remoteContract,
        uint256 in_remoteChainId
    )
        UsesCelerIM(in_messageBus)
        Spoke(in_remoteContract, in_remoteChainId)
    { }

    function pingMessage (bytes32 x) public pure returns (bytes memory) {
        return abi.encode(x);
    }

    function pingMessageLength () external pure returns (uint) {
        return 32;
    }

    function pingCost() external view returns (uint) {
        return _Spoke_transmissionCost(pingMessage(0).length);
    }

    function ping (bytes32 x) external payable {
        uint fee = _Spoke_send(pingMessage(x));
        require( msg.value == fee, "BAD FEE!" );
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

abstract contract MockPingPongUsingSpokeMessenger is UsesCelerIM, SpokeMessenger {

    bytes4 constant PING_SELECTOR = 0x01020304;

    constructor (
        ICelerMessageBus in_messageBus,
        address in_remoteContract,
        uint256 in_remoteChainId
    )
        UsesCelerIM(in_messageBus)
        SpokeMessenger(in_remoteContract, in_remoteChainId)
    { }

    function pingMessage (bytes32 x) public returns (bytes memory) {
        return _encodeMessage(PING_SELECTOR, abi.encode(x));
    }

    function pingMessageLength () public view returns (uint) {
        return _encodedMessageLength(32);
    }

    function pingCost() external view returns (uint) {
        return _transmissionCost(32);
    }

    function ping (bytes32 x) external payable {
        uint fee = _sendMessage(PING_SELECTOR, abi.encode(x));
        require( msg.value == fee, "BAD FEE!" );
    }

    function pong (bytes32 x) internal returns (ExecutionStatus) {
        emit Pong(x);
        return ExecutionStatus.Success;
    }

    function _receiveMessage(Message memory message, address /*in_executor*/)
        internal override
        returns (ExecutionStatus)
    {
        if( message.selector == PING_SELECTOR ) {
            return pong(abi.decode(message.data, (bytes32)));
        }

        return ExecutionStatus.Fail;
    }
}

contract MockPingPongUsingSpokeMessengerUnique is MockPingPongUsingSpokeMessenger, UniqueMessageEncoder, UniqueMessageDecoder {
    constructor (
        ICelerMessageBus in_messageBus,
        address in_remoteContract,
        uint256 in_remoteChainId
    )
        MockPingPongUsingSpokeMessenger(in_messageBus, in_remoteContract, in_remoteChainId)
    { }
}

/*
contract MockPingPongUsingSpokeMessengerSignedUnique is MockPingPongUsingSpokeMessenger, SignedUniqueMessageEncoder, SignedUniqueMessageDecoder {
    constructor (
        ICelerMessageBus in_messageBus,
        address in_remoteContract,
        uint256 in_remoteChainId
    )
        MockPingPongUsingSpokeMessenger(in_messageBus, in_remoteContract, in_remoteChainId)
    { }
}
*/