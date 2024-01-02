// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IPlugin } from "src/interfaces/IPlugin.sol";
import { Executor } from "src/libraries/Executor.sol";

import { SelfAuth } from "./SelfAuth.sol";

abstract contract PluginManager is SelfAuth {
    error PluginUnauthorized();
    error PluginExecutionForbidden();

    struct PluginConfig {
        bool enabled;
        mapping(address => mapping(bytes4 => bool)) permitted;
    }

    // TODO: Refactor to structured storage
    mapping(address => PluginConfig) plugins;

    modifier onlyAuthorizedPlugin(
        address to,
        uint256 value,
        bytes calldata data
    ) {
        bytes4 selector = bytes4(data[:4]);
        if (!plugins[msg.sender].permitted[to][selector]) {
            revert PluginExecutionForbidden();
        }
        _;
    }

    function addPlugin(
        IPlugin plugin,
        bytes calldata pluginInitData
    ) external onlySelf {
        _addPlugin(plugin, pluginInitData);
    }

    function _addPlugin(
        IPlugin plugin,
        bytes calldata pluginInitData
    ) internal {
        IPlugin.PluginPermission[] memory permissions =
            plugin.requiredPermissions();

        PluginConfig storage config = plugins[address(plugin)];
        config.enabled = true;
        for (uint256 i = 0; i < permissions.length; i++) {
            IPlugin.PluginPermission memory permission = permissions[i];
            address target = permission.target;
            for (uint256 j = 0; j < permission.selectors.length; j++) {
                config.permitted[target][permission.selectors[j]] = true;
            }
        }

        if (pluginInitData.length > 0) {
            Executor.call(address(plugin), 0, pluginInitData);
        }
    }

    function removePlugin(address plugin) external onlySelf {
        _removePlugin(plugin);
    }

    function _removePlugin(address plugin) internal {
        delete plugins[plugin];
    }

    function isPluginAuthorized(address plugin) external view returns (bool) {
        return plugins[plugin].enabled;
    }

    function executeFromPlugin(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyAuthorizedPlugin(to, value, data) {
        if (to == address(this)) {
            revert PluginExecutionForbidden();
        }
        Executor.call(to, value, data);
    }
}
