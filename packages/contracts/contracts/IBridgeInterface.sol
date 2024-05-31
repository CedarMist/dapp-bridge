// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import { ExecutionStatus } from "./common/Endpoint.sol";

struct ReceiverAndValue {
    address to;
    uint value;
}

uint constant ReceiverAndValue_ABIEncodedLength = 64;

interface BridgeRemoteEndpointAPI {
    function mint(ReceiverAndValue memory x) external returns (ExecutionStatus);

    function burn(address receiver, uint amount) external;
}
