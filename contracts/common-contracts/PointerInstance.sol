// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.0;

interface PointerInstance {
    function addPoints(
        address _player,
        uint256 _points,
        address _token,
        uint256 _numPlayers
    ) external returns (
        uint256 newPoints, uint256 multiplier);

    function addPoints(
        address _player,
        uint256 _points,
        address _token
    ) external returns (uint256 newPoints, uint256 multiplier);
}