// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vm } from "forge-std/Vm.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

struct Wallet {
    Vm vm;
    uint256 privateKey;
}

library WalletLib {
    using WalletLib for Wallet;

    function createRandomWallet(Vm vm) internal returns (Wallet memory) {
        string[] memory inputs = new string[](3);
        inputs[0] = "cast";
        inputs[1] = "wallet";
        inputs[2] = "new";

        bytes memory res = vm.ffi(inputs);
        uint256 privateKey =
            uint256(bytes32(BytesLib.slice(res, res.length - 64, 64)));

        return Wallet(vm, privateKey);
    }

    function addr(Wallet memory w) internal pure returns (address payable) {
        return payable(w.vm.addr(w.privateKey));
    }

    function balance(Wallet memory w) internal view returns (uint256) {
        return w.addr().balance;
    }

    function sign(
        Wallet memory w,
        bytes32 digest
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        return w.vm.sign(w.privateKey, digest);
    }

    function signEthSignedMessage(
        Wallet memory w,
        bytes32 digest
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        return w.sign(MessageHashUtils.toEthSignedMessageHash(digest));
    }
}

library BytesLib {
    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    ) internal pure returns (bytes memory) {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc :=
                    add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc :=
                        add(
                            add(
                                add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))
                            ),
                            _start
                        )
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } { mstore(mc, mload(cc)) }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                //zero out the 32 bytes slice we are about to return
                //we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }
}
