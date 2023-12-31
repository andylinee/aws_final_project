// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { IEntryPoint } from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOperation } from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";

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
        _addValidator(owner, wallet, nullValidator, bytes(""));
    }

    function testSetUp() public {
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

    function testConfigureOwnerValidator() public {
        Wallet memory newOwner = WalletLib.createRandomWallet(vm);

        UserOperation memory userOp = createUserOp(address(wallet));
        userOp.callData = abi.encodeCall(
            AAWallet.execute,
            (
                address(ownerValidator),
                0,
                abi.encodeCall(OwnerValidator.setOwner, (newOwner.addr()))
            )
        );
        signUserOpEthSignedMessage(owner, userOp);

        handleUserOp(userOp);

        assertEq(ownerValidator.owners(address(wallet)), newOwner.addr());
    }

    function testSetOwnerValidator() public {
        // Migrate to new owner validator
        Wallet memory newOwner = WalletLib.createRandomWallet(vm);
        OwnerValidator newOwnerValidator = new OwnerValidator();

        {
            UserOperation memory userOp = createUserOp(address(wallet));
            userOp.callData = abi.encodeCall(
                AAWallet.execute,
                (
                    address(wallet),
                    0,
                    abi.encodeCall(
                        AAWallet.setOwnerValidator,
                        (
                            newOwnerValidator,
                            abi.encodeCall(
                                OwnerValidator.setOwner, (newOwner.addr())
                                )
                        )
                        )
                )
            );
            signUserOpEthSignedMessage(owner, userOp);

            handleUserOp(userOp);
        }

        // Should not be able to manage account by old owner
        {
            UserOperation memory userOp = createUserOp(address(wallet));
            // Use old owner signature to set owner on new owner validator
            userOp.callData = abi.encodeCall(
                AAWallet.execute,
                (
                    address(newOwnerValidator),
                    0,
                    abi.encodeCall(OwnerValidator.setOwner, (owner.addr()))
                )
            );
            signUserOpEthSignedMessage(owner, userOp);

            expectRevertFailedOp("AA24 signature error");
            handleUserOp(userOp);
        }

        // Should be able to manage account by new owner
        {
            UserOperation memory userOp = createUserOp(address(wallet));
            // Use new owner signature to set owner on new owner validator
            userOp.callData = abi.encodeCall(
                AAWallet.execute,
                (
                    address(newOwnerValidator),
                    0,
                    abi.encodeCall(OwnerValidator.setOwner, (owner.addr()))
                )
            );
            signUserOpEthSignedMessage(newOwner, userOp);

            handleUserOp(userOp);

            assertEq(newOwnerValidator.owners(address(wallet)), owner.addr());
        }
    }

    function testCannotExecuteValidatorWhenNotAuthorized() public {
        OwnerValidator unauthroizedValidator = new OwnerValidator();

        UserOperation memory userOp = createUserOp(address(wallet));
        userOp.callData = abi.encodeCall(
            AAWallet.execute,
            (
                address(unauthroizedValidator),
                0,
                abi.encodeCall(OwnerValidator.setOwner, (address(0)))
            )
        );
        signUserOpEthSignedMessage(owner, userOp);

        vm.expectEmit(true, true, true, true);
        emit UserOperationRevertReason(
            getUserOpHash(userOp),
            address(wallet),
            userOp.nonce,
            abi.encodePacked(OwnerValidator.ValidatorUnauthorized.selector)
        );
        handleUserOp(userOp);
    }

    function testTransferThroughCustomValidator() public {
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

    function testTransferInBatchThroughCustomValidator() public {
        Wallet memory recipient = WalletLib.createRandomWallet(vm);

        address[] memory to = new address[](2);
        to[0] = recipient.addr();
        to[1] = recipient.addr();

        uint256[] memory value = new uint256[](2);
        value[0] = 0.1 ether;
        value[1] = 0.1 ether;

        bytes[] memory data = new bytes[](2);
        data[0] = bytes("");
        data[1] = bytes("");

        UserOperation memory userOp = createUserOp(address(wallet));
        userOp.callData =
            abi.encodeCall(AAWallet.executeBatch, (to, value, data));
        // Use null validator
        userOp.signature = abi.encodePacked(address(nullValidator));

        handleUserOp(userOp);

        assertEq(recipient.balance(), 0.2 ether);
    }

    function testCannotCallSelfThroughCustomValidator() public {
        UserOperation memory userOp = createUserOp(address(wallet));
        userOp.callData = abi.encodeCall(
            ValidatorManager.addValidator, (IValidator(address(0)), bytes(""))
        );
        // Use null validator
        userOp.signature = abi.encodePacked(address(nullValidator));

        expectRevertFailedOp("AA23 reverted (or OOG)");
        handleUserOp(userOp);
    }

    function testCannotExecuteSelfThroughCustomValidator() public {
        UserOperation memory userOp = createUserOp(address(wallet));
        userOp.callData = abi.encodeCall(
            AAWallet.execute,
            (
                address(wallet),
                0,
                abi.encodeCall(
                    ValidatorManager.addValidator,
                    (IValidator(address(0)), bytes(""))
                    )
            )
        );
        // Use null validator
        userOp.signature = abi.encodePacked(address(nullValidator));

        expectRevertFailedOp("AA23 reverted (or OOG)");
        handleUserOp(userOp);
    }

    function testCannotExecuteSelfInBatchThroughCustomValidator() public {
        Wallet memory recipient = WalletLib.createRandomWallet(vm);

        address[] memory to = new address[](2);
        to[0] = recipient.addr();
        to[1] = address(wallet);

        uint256[] memory value = new uint256[](2);
        value[0] = 0;
        value[1] = 0;

        bytes[] memory data = new bytes[](2);
        data[0] = bytes("");
        data[1] = abi.encodeCall(
            ValidatorManager.addValidator, (IValidator(address(0)), bytes(""))
        );

        UserOperation memory userOp = createUserOp(address(wallet));
        userOp.callData =
            abi.encodeCall(AAWallet.executeBatch, (to, value, data));
        // Use null validator
        userOp.signature = abi.encodePacked(address(nullValidator));

        expectRevertFailedOp("AA23 reverted (or OOG)");
        handleUserOp(userOp);
    }

    function testCannotExecuteValidatorThroughCustomValidator() public {
        UserOperation memory userOp = createUserOp(address(wallet));
        userOp.callData = abi.encodeCall(
            AAWallet.execute,
            (
                address(ownerValidator),
                0,
                abi.encodeCall(OwnerValidator.setOwner, (address(0)))
            )
        );
        // Use null validator
        userOp.signature = abi.encodePacked(address(nullValidator));

        expectRevertFailedOp("AA23 reverted (or OOG)");
        handleUserOp(userOp);
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
