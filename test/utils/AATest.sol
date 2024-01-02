// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";

import { EntryPoint } from "account-abstraction/core/EntryPoint.sol";
import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";
import {
    UserOperation, UserOperationLib
} from "account-abstraction/interfaces/UserOperation.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { Wallet, WalletLib } from "./Wallet.sol";

abstract contract AATest is Test {
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;
    using WalletLib for Wallet;

    IEntryPoint entryPoint = setupEntryPoint();

    /// @dev This function should be deterministic and cannot depend on other state variables
    function setupEntryPoint() internal virtual returns (IEntryPoint) {
        return new EntryPoint();
    }

    function createUserOp(address sender) internal view returns (UserOperation memory) {
        return UserOperation({
            sender: sender,
            nonce: entryPoint.getNonce(sender, 0),
            initCode: bytes(""),
            callData: bytes(""),
            callGasLimit: 999999,
            verificationGasLimit: 999999,
            preVerificationGas: 0,
            maxFeePerGas: 1 gwei,
            maxPriorityFeePerGas: 1 gwei,
            paymasterAndData: bytes(""),
            signature: bytes("")
        });
    }

    function handleUserOp(UserOperation memory userOp) internal {
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        entryPoint.handleOps(ops, payable(msg.sender));
    }

    function expectRevertFailedOp(string memory reason) internal {
        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, reason)
        );
    }

    function signUserOp(
        uint256 privateKey,
        UserOperation memory userOp
    ) internal view {
        bytes32 userOpHash = getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);
    }

    function signUserOp(
        Wallet memory signer,
        UserOperation memory userOp
    ) internal view {
        signUserOp(signer.privateKey, userOp);
    }

    function signUserOpEthSignedMessage(
        uint256 privateKey,
        UserOperation memory userOp
    ) internal view {
        bytes32 userOpHash = getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privateKey, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);
    }

    function signUserOpEthSignedMessage(
        Wallet memory signer,
        UserOperation memory userOp
    ) internal view {
        signUserOpEthSignedMessage(signer.privateKey, userOp);
    }

    function getUserOpHash(UserOperation memory userOp)
        internal
        view
        returns (bytes32)
    {
        return this._getUserOpHash(userOp);
    }

    function _getUserOpHash(UserOperation calldata userOp)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(userOp.hash(), address(entryPoint), block.chainid)
        );
    }

    function getUserOpMaxCost(UserOperation memory userOp)
        internal
        pure
        returns (uint256)
    {
        uint256 mul = userOp.paymasterAndData.length > 0 ? 3 : 1;
        return (
            userOp.callGasLimit + (userOp.verificationGasLimit * mul)
                + userOp.preVerificationGas
        ) * userOp.maxFeePerGas;
    }
}
