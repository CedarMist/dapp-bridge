// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

struct MintArgs {
    bytes32[2] sig;
    WithdrawArgs wd;
}

struct WithdrawArgs {
    address to;
    uint value;
}

function hash_keccak256(WithdrawArgs memory x) pure returns (bytes32) {
    return keccak256(abi.encode(x));
}

interface IBridgeInterface {
    function burn( address in_receiver, uint in_amount ) external;
}
