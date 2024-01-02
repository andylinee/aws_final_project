// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IValidator } from "src/interfaces/IValidator.sol";
import { Executor } from "src/libraries/Executor.sol";

import { SelfAuth } from "./SelfAuth.sol";

abstract contract ValidatorManager is SelfAuth {
    // TODO: Refactor to linked list
    mapping(address => bool) validators;

    function addValidator(
        IValidator validator,
        bytes calldata validatorInitData
    ) external onlySelf {
        validators[address(validator)] = true;
        Executor.call(address(validator), 0, validatorInitData);
    }

    function removeValidator(IValidator validator) external onlySelf {
        delete validators[address(validator)];
    }
}
