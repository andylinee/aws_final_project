// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IEntryPoint } from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOperation } from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { PluginManager } from "./base/PluginManager.sol";
import { SelfAuth } from "./base/SelfAuth.sol";
import { ValidatorManager } from "./base/ValidatorManager.sol";
import { IValidator } from "./interfaces/IValidator.sol";
import { Executor } from "./libraries/Executor.sol";

contract AAWallet is Initializable, UUPSUpgradeable, SelfAuth, ValidatorManager, PluginManager {
    IEntryPoint public immutable entryPoint;
    IValidator public ownerValidator;

    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
    }

    function initialize(
        IValidator _ownerValidator,
        bytes calldata _ownerValidatorInitData
    ) external initializer {
        ownerValidator = _ownerValidator;
        _addValidator(_ownerValidator, _ownerValidatorInitData);
    }

    receive() external payable { }

    modifier onlyEntryPoint() {
        require(msg.sender == address(entryPoint));
        _;
    }

    function setOwnerValidator(
        IValidator _ownerValidator,
        bytes calldata _ownerValidatorInitData
    ) external onlySelf {
        IValidator prevOwnerValidator = ownerValidator;
        ownerValidator = _ownerValidator;
        _addValidator(_ownerValidator, _ownerValidatorInitData);
        // Remove previous owner validator to avoid executing wallet by outdated validation mechanism.
        _removeValidator(prevOwnerValidator);
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256 validationData) {
        IValidator validator = _getValidator(userOp);
        validationData = validator.validateUserOp(userOp, userOpHash);

        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{
                value: missingAccountFunds,
                gas: gasleft()
            }("");
            // ignore failure (This verification is EntryPoint's, not Account.)
            (success);
        }
    }

    function _getValidator(UserOperation calldata userOp)
        internal
        view
        returns (IValidator)
    {
        bytes4 selector = bytes4(userOp.callData[:4]);

        if (selector == AAWallet.execute.selector) {
            address to = abi.decode(userOp.callData[4:], (address));
            // If execution target is account itself or validator,
            // the call requires to be validated by owner validator.
            if (to == address(this) || validators[to]) {
                return ownerValidator;
            }

            // Allow custom validator when not calling to account itself.
            address validator =
                address(bytes20(userOp.signature[:20]));
            if (validators[validator]) {
                return IValidator(validator);
            }
            // If custom validator is not valid, fallback to owner validator.
            return ownerValidator;
        }

        if (selector == AAWallet.executeBatch.selector) {
            address[] memory to = abi.decode(userOp.callData[4:], (address[]));
            for (uint256 i; i < to.length; i++) {
                // If at least one execution target is account itself or validator,
                // the call requires to be validated by owner validator.
                if (to[i] == address(this) || validators[to[i]]) {
                    return ownerValidator;
                }
            }
            // Allow custom validator when not calling to account itself.
            address validator =
                address(bytes20(userOp.signature[:20]));
            if (validators[validator]) {
                return IValidator(validator);
            }
            // If custom validator is not valid, fallback to owner validator.
            return ownerValidator;
        }
        // For other functions on wallet, it must require validated by owner validator.
        return ownerValidator;
    }

    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyEntryPoint {
        Executor.call(to, value, data);
    }

    function executeBatch(
        address[] calldata to,
        uint256[] calldata value,
        bytes[] calldata data
    ) external onlyEntryPoint {
        require(
            to.length == value.length && to.length == data.length,
            "wrong array lengths"
        );
        for (uint256 i = 0; i < to.length; i++) {
            Executor.call(to[i], value[i], data[i]);
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlySelf
    { }
}
