// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {Enclave,Result} from "@oasisprotocol/sapphire-contracts/contracts/OPL.sol";
//import {Sapphire} from "@oasisprotocol/sapphire-contracts/contracts/Sapphire.sol";
import {EthereumUtils,SignatureRSV} from "@oasisprotocol/sapphire-contracts/contracts/EthereumUtils.sol";

contract EndpointOnSapphire is Enclave {
    bytes32 private signingSecret;
    address public signingPublic;

    uint remoteBalance;

    constructor (address in_host, bytes32 in_hostChain)
        Enclave(in_host, in_hostChain)
    {
        (signingPublic, signingSecret) = EthereumUtils.generateKeypair();

        registerEndpoint("withdraw()", _withdraw);
    }

    function deposit(address in_to)
        public payable
    {
        require( msg.value > 0 );

        remoteBalance += msg.value;

        bytes memory message = abi.encodePacked(in_to, msg.value);

        bytes32 messageDigest = keccak256(message);

        SignatureRSV memory rsv = EthereumUtils.sign(
            signingPublic, signingSecret, messageDigest);

        bytes32 vs = bytes32((rsv.v << 255) | uint(rsv.s));

        bytes memory signedMessage = abi.encode(rsv.r, vs, in_to, msg.value);

        postMessage("mint()", signedMessage);
    }

    receive() external payable {
        deposit(msg.sender);
    }

    function _withdraw(bytes calldata in_data)
        internal
        returns (Result)
    {
        (address arg_to, uint arg_amount) = abi.decode(in_data, (address, uint));

        remoteBalance -= arg_amount;

        payable(arg_to).transfer(arg_amount);

        return Result.Success;
    }
}