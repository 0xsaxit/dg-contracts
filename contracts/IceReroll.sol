// SPDX-License-Identifier: ---DG---

pragma solidity ^0.8.13;

import "./common-contracts/TransferHelper.sol";
import "./common-contracts/AccessController.sol";

interface IceRegistrant {

    function adjustRegistrantEntry(
        address _tokenOwner,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _bonusValue,
        uint256 _levelValue
    )
        external;

    function getLevel(
        address _tokenOwner,
        bytes32 _tokenHash
    )
        external
        view
        returns (uint256);

    function getHash(
        address _tokenAddress,
        uint256 _tokenId
    )
        external
        pure
        returns (bytes32);

    function levels(
        uint256 _level
    )
        external
        view
        returns (
            bool isActive,
            uint256 costAmountDG,
            uint256 moveAmountDG,
            uint256 costAmountICE,
            uint256 moveAmountICE,
            uint256 floorBonus,
            uint256 deltaBonus
        );

    function getNumber(
        uint256 _floorValue,
        uint256 _deltaValue,
        uint256 _nonceValue,
        uint256 _randomValue
    )
        external
        pure
        returns (uint256);
}

interface IceToken {

    function burn(
        uint256 _amount
    )
        external;
}

contract IceReroll is AccessController, TransferHelper {

    uint256 public purchaseCount;
    uint256 public iceRerollPrice;

    address public immutable iceTokenAddress;
    IceRegistrant public immutable registrantContract;

    constructor(
        uint256 _iceRerollPrice,
        address _iceTokenAddress,
        IceRegistrant _registrantContract
    ) {
        iceRerollPrice = _iceRerollPrice;
        iceTokenAddress = _iceTokenAddress;
        registrantContract = _registrantContract;
    }

    function enableReroll(
        address _tokenOwner,
        address _tokenAddress,
        uint256 _tokenId
    )
        external
        onlyWorker
    {
        bytes32 tokenHash = registrantContract.getHash(
            _tokenAddress,
            _tokenId
        );

        uint256 currentLevel = registrantContract.getLevel(
            _tokenOwner,
            tokenHash
        );

        require(
            currentLevel > 0,
            "IceReroll: INVALID_INPUT"
        );

        unchecked {
            purchaseCount =
            purchaseCount + 1;
        }

        (
            ,
            ,
            ,
            ,
            ,
            uint256 floorBonus,
            uint256 deltaBonus
        )

        = registrantContract.levels(
            currentLevel
        );

        uint256 newBonusReroll = registrantContract.getNumber(
            floorBonus,
            deltaBonus,
            purchaseCount,
            block.timestamp
        );

        registrantContract.adjustRegistrantEntry(
            _tokenOwner,
            _tokenAddress,
            _tokenId,
            newBonusReroll,
            currentLevel
        );

        safeTransferFrom(
            iceTokenAddress,
            _tokenOwner,
            address(this),
            iceRerollPrice
        );

        IceToken(iceTokenAddress).burn(
            iceRerollPrice
        );
    }

    function updatePrice(
        uint256 _iceRerollPrice
    )
        external
        onlyCEO
    {
        iceRerollPrice = _iceRerollPrice;
    }
}
