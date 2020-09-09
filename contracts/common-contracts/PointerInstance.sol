// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.0;

interface PointerInstance {
    function addPoints(
        address _player,
        uint256 _points
    ) external returns (bool);
}

