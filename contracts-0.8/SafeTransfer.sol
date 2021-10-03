// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.8.7;

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
) {
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

bytes4 constant BALANCE_OF = bytes4(
    keccak256(
        bytes(
            'balanceOf(address)'
        )
    )
);

function safeBalanceOf(
    address _token,
    address _owner
)
    returns (uint256)
{
    (bool success, bytes memory data) = _token.call(
        abi.encodeWithSelector(
            BALANCE_OF,
            _owner
        )
    );
    if (!success) return 0;
    return abi.decode(data, (uint256));
}
