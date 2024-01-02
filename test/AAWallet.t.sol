// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";

import { ValidatorManager } from "src/base/ValidatorManager.sol";
import { IValidator } from "src/interfaces/IValidator.sol";
import { NullValidator } from "src/validators/NullValidator.sol";
import { OwnerValidator } from "src/validators/OwnerValidator.sol";
import { AAWallet } from "src/AAWallet.sol";
import { AAWalletFactory } from "src/AAWalletFactory.sol";

import { AATest } from "./utils/AATest.sol";
import { Wallet, WalletLib } from "./utils/Wallet.sol";

contract AAWalletTest is AATest {
    using WalletLib for Wallet;

    NullValidator nullValidator = new NullValidator();
    OwnerValidator ownerValidator = new OwnerValidator();

    AAWalletFactory walletFactory =
        new AAWalletFactory(entryPoint, ownerValidator);
    Wallet owner = WalletLib.createRandomWallet(vm);
    AAWallet wallet = walletFactory.createAccount(owner.addr(), 0x1234);

    function setUp() public {
        vm.deal(address(wallet), 1 ether);
    }

    function testSetUp() public {
        assertEq(address(wallet).balance, 1 ether);
        assertEq(ownerValidator.owners(address(wallet)), owner.addr());
    }

    function testTransfer() public {
        Wallet memory recipient = WalletLib.createRandomWallet(vm);

        UserOperation memory userOp = createUserOp(address(wallet));
        userOp.callData = abi.encodeCall(
            AAWallet.execute, (recipient.addr(), 0.1 ether, bytes(""))
        );
        signUserOpEthSignedMessage(owner, userOp);

        handleUserOp(userOp);

        assertEq(recipient.balance(), 0.1 ether);
    }

    function testTransferByCustomValidator() public {
        _addValidator(owner, wallet, nullValidator, bytes(""));

        Wallet memory recipient = WalletLib.createRandomWallet(vm);

        UserOperation memory userOp = createUserOp(address(wallet));
        userOp.callData = abi.encodeCall(
            AAWallet.execute, (recipient.addr(), 0.1 ether, bytes(""))
        );
        // Use null validator
        userOp.signature = abi.encodePacked(address(nullValidator));

        handleUserOp(userOp);

        assertEq(recipient.balance(), 0.1 ether);
    }

    function _addValidator(
        Wallet memory _owner,
        AAWallet _wallet,
        IValidator _validator,
        bytes memory _validatorInitData
    ) internal {
        UserOperation memory userOp = createUserOp(address(_wallet));
        userOp.callData = abi.encodeCall(
            AAWallet.execute,
            (
                address(_wallet),
                0,
                abi.encodeCall(
                    ValidatorManager.addValidator,
                    (_validator, _validatorInitData)
                    )
            )
        );
        signUserOpEthSignedMessage(_owner, userOp);

        handleUserOp(userOp);
    }
}
