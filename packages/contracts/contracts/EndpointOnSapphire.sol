// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {Enclave,Result} from "@oasisprotocol/sapphire-contracts/contracts/OPL.sol";
import {MintArgs,WithdrawArgs} from "./IBridgeInterface.sol";
import {EthereumUtils,SignatureRSV} from "@oasisprotocol/sapphire-contracts/contracts/EthereumUtils.sol";
import {eip2098} from "./eip2098.sol";

contract EndpointOnSapphire is Enclave {
    bytes32 private signingSecret;
    address public signingPublic;
    uint private remoteBalance;

    constructor (address in_host, bytes32 in_hostChain)
        Enclave(in_host, in_hostChain)
    {
        (signingPublic, signingSecret) = EthereumUtils.generateKeypair();

        registerEndpoint("withdraw()", _withdraw);
    }

    function deposit(address to)
        public payable
    {
        WithdrawArgs memory wd = WithdrawArgs({to: to, value: msg.value});

        MintArgs memory ma = MintArgs({
                    wd: wd,
                    sig: eip2098(
                        EthereumUtils.sign(
                            signingPublic,
                            signingSecret,
                            keccak256(abi.encode(wd))))
                    });

        postMessage("mint()", abi.encode(ma));

        remoteBalance += msg.value;
    }

    receive() external payable {

        deposit(msg.sender);
    }

    function _withdraw(bytes calldata in_data)
        internal
        returns (Result)
    {
        (WithdrawArgs memory x) = abi.decode(in_data, (WithdrawArgs));

        remoteBalance -= x.value;

        payable(x.to).transfer(x.value);

        return Result.Success;
    }
}
