// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {Host,Result} from "@oasisprotocol/sapphire-contracts/contracts/OPL.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {WrappedROSE} from "./WrappedROSE.sol";
import {eip2098} from "./eip2098.sol";
import "./IBridgeInterface.sol";

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

    function burn( address receiver, uint amount ) external {

        require( msg.sender == address(token) );

        require( amount > 0 );

        postMessage("withdraw()",
            abi.encode(
                WithdrawArgs({
                    to: receiver,
                    value: amount
                    })));
    }

    /// Mint instruction received via CelerIM
    function _mint(bytes calldata _data)
        internal
        returns (Result)
    {
        MintArgs memory x = abi.decode(_data, (MintArgs));

        bytes32 digest = hash_keccak256(x.wd);

        address signer = ECDSA.recover(digest, x.sig[0], x.sig[1]);

        require( signer == signerOnSapphire );

        token.mint(x.wd.to, x.wd.value);

        return Result.Success;
    }
}
