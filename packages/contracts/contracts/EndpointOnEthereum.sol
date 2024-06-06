// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { WrappedROSE } from "./WrappedROSE.sol";
import { SpokeMessenger, Message } from "./common/Message.sol";
import { ExecutionStatus } from "./common/Endpoint.sol";
import { UsesCelerIM, ICelerMessageBus } from "./common/CelerIM.sol" ;
import { UniqueMessageEncoder, SignedUniqueMessageDecoder } from "./common/SignedUniqueMessage.sol";
import { BridgeRemoteEndpointAPI, ReceiverAndValue, ReceiverAndValue_ABIEncodedLength, Pong } from "./IBridgeInterface.sol";

/**
 * Spoke part of the bridge
 *  - Receives signed 'mint' instructions from Sapphire
 *  - Mints ERC20 (wROSE)
 *  - Upon burning wROSE, sends 'withdraw' instructions to Sapphire
 *  - Requires payment in native gas currency to burn
 */
contract EndpointOnEthereum is UniqueMessageEncoder, SignedUniqueMessageDecoder, SpokeMessenger, UsesCelerIM
{
    WrappedROSE public token;

    constructor (
        ICelerMessageBus in_msgbus,
        address in_remoteContract,
        uint in_remoteChainId,
        address in_remoteSigner
    )
        UsesCelerIM(in_msgbus)
        SpokeMessenger(in_remoteContract, in_remoteChainId)
        SignedUniqueMessageDecoder(in_remoteSigner)
    {
        token = new WrappedROSE();
    }

    /// Cost (in native gas currency) to send a burn message
    function burnCost()
        public view
        returns (uint)
    {
        return _transmissionCost(ReceiverAndValue_ABIEncodedLength);
    }

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

    function burn(uint value)
        public
    {
        return burn(value, msg.sender);
    }

    function burn(uint value, address receiver)
        public payable
    {
        require( msg.sender == address(token) );

        uint fee = _sendMessage(
            BridgeRemoteEndpointAPI.burn.selector,
            abi.encode(ReceiverAndValue(receiver, value)));

        // Refund any excess fee
        if( msg.value > fee )
        {
            payable(msg.sender).transfer(msg.value - fee);
        }
    }

    function _receiveMessage(Message memory message, address /*in_executor*/)
        internal override
        returns (ExecutionStatus)
    {
        if( message.selector == BridgeRemoteEndpointAPI.mint.selector )
        {
            return mint(abi.decode(message.data, (ReceiverAndValue)));
        }

        if( message.selector == BridgeRemoteEndpointAPI.pong.selector )
        {
            return pong(abi.decode(message.data, (bytes32)));
        }

        return ExecutionStatus.Fail;
    }

    function mint(ReceiverAndValue memory x)
        internal
        returns (ExecutionStatus)
    {
        token.mint(x.to, x.value);

        return ExecutionStatus.Success;
    }
}
