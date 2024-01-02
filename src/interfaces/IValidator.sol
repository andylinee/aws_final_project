// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";

// IValidator is just served as an example, not the final specification.
interface IValidator {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns (uint256 validationData);
}
