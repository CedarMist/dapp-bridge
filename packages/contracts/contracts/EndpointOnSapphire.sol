// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { UsesCelerIM, ICelerMessageBus } from "./common/CelerIM.sol" ;
import { ReceiverAndValue, BridgeRemoteEndpointAPI,
         ReceiverAndValue_ABIEncodedLength, Pong } from "./IBridgeInterface.sol";
import { SpokeSUMSender_UniqueMessageReceiver } from "./common/SignedUniqueMessage.sol";
import { ExecutionStatus, MessageContext, MessageReceiver, Message } from "./common/Endpoint.sol";

contract EndpointOnSapphire is UsesCelerIM, SpokeSUMSender_UniqueMessageReceiver
{
    uint public remoteBalance;

    constructor (
        ICelerMessageBus in_msgbus,
        address in_remoteContract,
        uint in_remoteChainId
    )
        UsesCelerIM(in_msgbus)
        SpokeSUMSender_UniqueMessageReceiver(in_remoteContract, in_remoteChainId)
    { }

    function ping(bytes32 x)
        external payable
    {
        uint fee = _sendMessage(BridgeRemoteEndpointAPI.pong.selector, abi.encode(x));
        if( msg.value > fee ) {
            payable(msg.sender).transfer(msg.value - fee);
        }
    }

    function pong(bytes32 x)
        internal
        returns (ExecutionStatus)
    {
        emit Pong(x);

        return ExecutionStatus.Success;
    }

    function depositCost()
        public view
        returns (uint)
    {
        return _transmissionCost(ReceiverAndValue_ABIEncodedLength);
    }

    /**
     * Receives native gas token, mints equivalent token on remote chain
     *
     * Subtracts message transmission cost from deposit amount
     *
     * @param to Address on remote chain to mint tokens for
     */
    function deposit(address to)
        public payable
    {
        uint fee = depositCost();

        uint amount = msg.value - fee;

        _sendMessage(
            BridgeRemoteEndpointAPI.mint.selector,
            abi.encode(ReceiverAndValue(to, amount)),
            fee);

        remoteBalance += amount;
    }

    function deposit()
        public payable
    {
        return deposit(msg.sender);
    }

    receive() external payable
    {
        deposit(msg.sender);
    }

    function _receiveMessage(Message memory message, address /*in_executor*/)
        internal override
        returns (ExecutionStatus)
    {
        if( message.selector == BridgeRemoteEndpointAPI.burn.selector )
        {
            return burn(abi.decode(message.data, (ReceiverAndValue)));
        }

        if( message.selector == BridgeRemoteEndpointAPI.pong.selector )
        {
            return pong(abi.decode(message.data, (bytes32)));
        }

        return ExecutionStatus.Fail;
    }

    function burn(ReceiverAndValue memory in_arg)
        internal
        returns (ExecutionStatus)
    {
        remoteBalance -= in_arg.value;

        payable(in_arg.to).transfer(in_arg.value);

        return ExecutionStatus.Success;
    }
}
