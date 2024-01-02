// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// IPlugin is just served as an example, not the final specification.
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