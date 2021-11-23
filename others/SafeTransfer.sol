// SPDX-License-Identifier: -- ICE --

pragma solidity ^0.8.9;

interface ERC20 {

    function balanceOf(
        address _iceKeeper
    )
        external
        view
        returns (uint256);
}

contract SafeTransfer {

    bytes4 constant TRANSFER = bytes4(
        keccak256(
            bytes(
                'transfer(address,uint256)'
            )
        )
    );

    function safeTransfer(
        address _token,
        address _to,
        uint256 _value
    )
      internal
    {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(
                TRANSFER,
                _to,
                _value
            )
        );

        require(
            success && (
                data.length == 0 || abi.decode(
                    data, (bool)
                )
            ),
            'TransferHelper: TRANSFER_FAILED'
        );
    }
}
