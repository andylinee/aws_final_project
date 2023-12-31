// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

import { OwnerValidator } from "./validator/OwnerValidator.sol";

import { AAWallet } from "./AAWallet.sol";

contract AAWalletFactory {
    AAWallet public immutable accountImplementation;
    OwnerValidator public immutable ownerValidator;

    constructor(IEntryPoint _entryPoint, OwnerValidator _ownerValidator) {
        accountImplementation = new AAWallet(_entryPoint);
        ownerValidator = _ownerValidator;
    }

    function createAccount(
        address owner,
        uint256 salt
    ) public returns (AAWallet) {
        address addr = getAddress(owner, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return AAWallet(payable(addr));
        }
        return AAWallet(
            payable(
                new ERC1967Proxy{salt : bytes32(salt)}(
                    address(accountImplementation),
                    abi.encodeCall(
                        AAWallet.initialize, 
                        (
                            ownerValidator, 
                            abi.encodeCall(OwnerValidator.setOwner, (owner))
                        )
                    )
                )
            )
        );
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(
        address owner,
        uint256 salt
    ) public view returns (address) {
        return Create2.computeAddress(
            bytes32(salt),
            keccak256(
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(
                        address(accountImplementation),
                        abi.encodeCall(
                            AAWallet.initialize,
                            (
                                ownerValidator,
                                abi.encodeCall(OwnerValidator.setOwner, (owner))
                            )
                        )
                    )
                )
            )
        );
    }
}
