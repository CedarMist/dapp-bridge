// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { ICelerMessageBus, ICelerMessageReceiver } from "../common/CelerIM.sol";

/**
 * Allows us to simulate contracts on multiple chains via a single mock msg bus
 *
 * Each contract has a chain ID and optional overriden contract address
 * associated with it, meaning you can simulate contracts with the same address
 * on multiple chains and allow them to interact with each other.
 *
 * You must call `deliver()` repeatedly until it returns 0 (the count of
 * undelivered messages).
 */
contract MockCelerMessageBus {

    struct Remapping {
        ICelerMessageReceiver remoteContract;
        uint64 remoteChainId;
        address localContract;
    }

    struct SentMessage {
        Remapping origin;
        Remapping dest;
        bytes data;
        address executor;
        uint cost;
        bool isDelivered;
    }

    mapping(bytes32 => ICelerMessageReceiver) public remoteToLocal;

    mapping(ICelerMessageReceiver => Remapping) public localToRemote;

    SentMessage[] public messages;

    uint public undeliveredCount;

    uint public deliveredCount;

    function _remappingHash(
        address in_remoteContract,
        uint256 in_remoteChainId
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(in_remoteContract, in_remoteChainId));
    }

    function addContract(
        ICelerMessageReceiver in_remoteContract,
        uint64 in_remoteChainId
    )
        external
    {
        return addContract(in_remoteContract, in_remoteChainId, in_remoteContract);
    }

    /// Contracts must be mapped to be accessible via the bridge
    function addContract(
        ICelerMessageReceiver in_remoteContract,
        uint64 in_remoteChainId,
        ICelerMessageReceiver in_localContract
    )
        public
    {
        bytes32 rh = _remappingHash(address(in_remoteContract), in_remoteChainId);

        require( address(remoteToLocal[rh]) == address(0), "DUPLICATE R2L MAPPING!" );

        require( localToRemote[in_localContract].remoteChainId == 0, "DUPLICATE L2R MAPPING!" );

        remoteToLocal[rh] = ICelerMessageReceiver(in_localContract);

        localToRemote[in_localContract] = Remapping(
            in_remoteContract,
            in_remoteChainId,
            address(in_localContract));
    }

    // We choose some arbitrary but distinct amount for base & per-byte fees
    function feeBase() public pure returns (uint256)
    {
        return 543210 gwei;
    }

    function feePerByte() public pure returns (uint256)
    {
        return 123456 gwei;
    }

    function calcFee(bytes calldata _message) public pure returns (uint256)
    {
        return feeBase() + (_message.length * feePerByte());
    }

    function sendMessage(
        address in_remoteContract,
        uint256 in_remoteChainId,
        bytes calldata in_message
    )
        external payable
    {
        // Local contract sending message must be mapped

        Remapping memory local = localToRemote[ICelerMessageReceiver(msg.sender)];

        require( local.remoteChainId != 0, "NO MSGBUS LOCAL MAPPING!" );

        // Destination contract to receive message must also be mapped

        bytes32 rh = _remappingHash(in_remoteContract, in_remoteChainId);

        ICelerMessageReceiver remote = remoteToLocal[rh];

        require( address(remote) != address(0), "NO MSGBUS REMOTE MAPPING!" );

        // Collect fees

        uint cost = feeBase() + (feePerByte() * in_message.length);

        require( msg.value >= cost, "INSUFFICIENT FEE!" );

        // Add message to list to be delivered later

        messages.push(SentMessage(
            local,
            localToRemote[remote],
            in_message,
            tx.origin,
            cost,
            false
        ));

        undeliveredCount += 1;

        // Refund any excess fees

        if( msg.value > cost )
        {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }

    function deliverOneMessage ()
        external
        returns (uint out_remainingUndelivered)
    {
        if( undeliveredCount > 0 )
        {
            SentMessage storage m = messages[deliveredCount];

            uint result = m.dest.remoteContract.executeMessage(
                address(m.origin.remoteContract),
                m.origin.remoteChainId,
                m.data,
                msg.sender);

            require( result == 1, "BAD ExecutionStatus!" );

            undeliveredCount -= 1;

            deliveredCount += 1;

            m.executor = msg.sender;

            m.isDelivered = true;
        }

        return undeliveredCount;
    }
}
