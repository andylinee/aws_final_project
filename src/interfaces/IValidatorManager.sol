// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IValidatorManager {
    function isValidatorAuthorized(address validator)
        external
        view
        returns (bool);
}