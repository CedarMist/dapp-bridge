// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

interface IBridgeInterface {
    function burn( address in_receiver, uint in_amount ) external;
}
