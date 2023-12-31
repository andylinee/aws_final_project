// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { IValidator } from "./validator/IValidator.sol";

contract Account is Initializable, UUPSUpgradeable {
    address public entryPoint;
    IValidator public ownerValidator;

    constructor(address _entryPoint) {
        entryPoint = _entryPoint;
    }

    function initialize(
        IValidator _ownerValidator,
        bytes calldata _ownerValidatorInitData
    ) external initializer {
        ownerValidator = _ownerValidator;
        _call(address(_ownerValidator), 0, _ownerValidatorInitData);
    }

    receive() external payable { }

    modifier onlyEntryPoint() {
        require(msg.sender == entryPoint);
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this));
        _;
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256 validationData) {
        IValidator validator = _getValidator(userOp.callData);
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

    function _getValidator(bytes calldata callData)
        internal
        view
        returns (IValidator)
    {
        bytes4 selector = bytes4(callData[:4]);
        if (selector == Account.execute.selector) {
            address to = abi.decode(callData[4:], (address));
            // TODO: Also check `to` includes validator or not
            if (to == address(this)) {
                return ownerValidator;
            }
            // TODO: Extract validator from `signature`
        }
        return ownerValidator;
    }

    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyEntryPoint {
        _call(to, value, data);
    }

    function _call(
        address target,
        uint256 value,
        bytes calldata data
    ) internal {
        (bool success, bytes memory result) = target.call{ value: value }(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlySelf
    { }
}
