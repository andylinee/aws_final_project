// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";

import { IValidator } from "src/interfaces/IValidator.sol";

contract NullValidator is IValidator {
    function validateUserOp(
        UserOperation calldata, /* userOp */
        bytes32 /* userOpHash */
    ) external pure returns (uint256 validationData) {
        return 0;
    }
}
