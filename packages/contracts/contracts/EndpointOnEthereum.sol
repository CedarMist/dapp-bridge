// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {Host,Result} from "@oasisprotocol/sapphire-contracts/contracts/OPL.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {WrappedROSE} from "./WrappedROSE.sol";
import {IBridgeInterface} from "./IBridgeInterface.sol";

contract EndpointOnEthereum is Host {
    address private signerOnSapphire;
    WrappedROSE public token;

    constructor (address in_signer, address in_enclave)
        Host(in_enclave)
    {
        signerOnSapphire = in_signer;

        registerEndpoint("mint()", _mint);

        token = new WrappedROSE();
    }

    function burn( address in_receiver, uint in_amount ) external {
        require( msg.sender == address(token) );
        require( in_amount > 0 );

        bytes memory message = abi.encode(in_receiver, in_amount);

        postMessage("withdraw()", message);
    }

    /// Mint instruction received via CelerIM
    function _mint(bytes calldata in_data)
        internal
        returns (Result)
    {
        bytes32 arg_r;
        bytes32 arg_vs;
        address arg_to;
        uint arg_value;

        (arg_r, arg_vs, arg_to, arg_value) = abi.decode(in_data, (bytes32,bytes32,address,uint));

        bytes32 messageDigest = keccak256(abi.encodePacked(arg_to, arg_value));

        address messageSigner = ECDSA.recover(messageDigest, arg_r, arg_vs);

        require( messageSigner == signerOnSapphire );

        token.mint(arg_to, arg_value);

        return Result.Success;
    }
}
