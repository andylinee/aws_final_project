// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPlugin {
    struct PluginPermission {
        address target;
        bytes4[] selectors;
    }

    function requiredPermissions()
        external
        pure
        returns (PluginPermission[] memory);
}