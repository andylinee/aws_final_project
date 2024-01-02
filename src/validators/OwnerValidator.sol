// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { IValidator } from "src/interfaces/IValidator.sol";
import { IValidatorManager } from "src/interfaces/IValidatorManager.sol";

contract OwnerValidator is IValidator {
    error ValidatorUnauthorized();

    using ECDSA for bytes32;

    modifier whenValidatorAuthorized() {
        // Skip for initialize phase
        if (msg.sender.code.length > 0) {
            if (
                !IValidatorManager(msg.sender).isValidatorAuthorized(
                    address(this)
                )
            ) {
                revert ValidatorUnauthorized();
            }
        }
        _;
    }

    mapping(address => address) public owners;

    function setOwner(address owner) external whenValidatorAuthorized {
        owners[msg.sender] = owner;
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) external view whenValidatorAuthorized returns (uint256 validationData) {
        address owner = owners[msg.sender];
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner != hash.recover(userOp.signature)) {
            return 1;
        }
        return 0;
    }
}
