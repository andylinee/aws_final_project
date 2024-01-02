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
        _addValidator(validator, validatorInitData);
    }

    function _addValidator(
        IValidator validator,
        bytes calldata validatorInitData
    ) internal {
        validators[address(validator)] = true;
        if (validatorInitData.length > 0) {
            Executor.call(address(validator), 0, validatorInitData);
        }
    }

    function removeValidator(IValidator validator) external onlySelf {
        _removeValidator(validator);
    }

    function _removeValidator(IValidator validator) internal {
        delete validators[address(validator)];
    }
}
