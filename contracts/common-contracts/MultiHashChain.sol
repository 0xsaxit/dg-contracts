// SPDX-License-Identifier: ---DG----

pragma solidity ^0.8.7;

contract MultiHashChain {

    mapping(uint256 => bytes32) public tail;

    function _setMachineTail(
        uint256 _machineId,
        bytes32 _tail
    ) internal {
        tail[_machineId] = _tail;
    }

    function _consumeMachineHash(
        uint256 _machineId,
        bytes32 _parent
    ) internal {
        require(
            keccak256(
                abi.encodePacked(
                    _parent
                )
            ) == tail[_machineId],
            'MultiHashChain: invalid hash for machine'
        );
        tail[_machineId] = _parent;
    }
}
