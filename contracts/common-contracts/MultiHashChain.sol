// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.0;

contract MultiHashChain {

    mapping(
        uint256 => mapping(
            uint256 => mapping(
                uint256 => bytes32
            )
        )
    ) public tail;

    function _setMultiTail(
        uint256 tableID,
        uint256 landID,
        uint256 serverID,
        bytes32 _tail
    ) internal {
        tail[serverID][landID][tableID] = _tail;
    }

    function _consumeMulti(
        uint256 tableID,
        uint256 landID,
        uint256 serverID,
        bytes32 _parent
    ) internal {
        require(
            keccak256(
                abi.encodePacked(_parent)
            ) == tail[serverID][landID][tableID],
            'hash-chain: wrong parent'
        );
        tail[serverID][landID][tableID] = _parent;
    }
}