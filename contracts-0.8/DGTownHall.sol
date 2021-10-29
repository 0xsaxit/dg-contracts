// SPDX-License-Identifier: DG

pragma solidity ^0.8.9;

interface DGToken {

    function balanceOf(
        address _account
    )
        external
        view
        returns (uint256);

    function transfer(
        address _recipient,
        uint256 _amount
    )
        external
        returns (bool);

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        external
        returns (bool);
}

contract ERC20 {

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 _value
    );

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    constructor(
        string memory _entryname,
        string memory _entrysymbol
    ) {
        _name = _entryname;
        _symbol = _entrysymbol;
        _decimals = 18;
    }

    function name()
        public
        view
        returns (string memory)
    {
        return _name;
    }

    function symbol()
        public
        view
        returns (string memory)
    {
        return _symbol;
    }

    function decimals()
        public
        view
        returns (uint8)
    {
        return _decimals;
    }

    function totalSupply()
        public
        view
        returns (uint256)
    {
        return _totalSupply;
    }

    function balanceOf(
        address account
    )
        public
        view
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    )
        external
        returns (bool)
    {
        _transfer(
            msg.sender,
            recipient,
            amount
        );

        return true;
    }

    function allowance(
        address owner,
        address spender
    )
        external
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    )
        external
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            amount
        );

        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        public
        returns (bool)
    {
        _approve(
            _sender,
            msg.sender,
            _allowances[_sender][msg.sender] - _amount
        );

        _transfer(
            _sender,
            _recipient,
            _amount
        );

        return true;
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        internal
    {
        _balances[_sender] =
        _balances[_sender] - _amount;

        _balances[_recipient] =
        _balances[_recipient] + _amount;

        emit Transfer(
            _sender,
            _recipient,
            _amount
        );
    }

    function _mint(
        address _account,
        uint256 _amount
    )
        internal
    {
        _totalSupply =
        _totalSupply + _amount;

        _balances[_account] =
        _balances[_account] + _amount;

        emit Transfer(
            address(0x0),
            _account,
            _amount
        );
    }

    function _burn(
        address _account,
        uint256 _amount
    )
        internal
    {
        _balances[_account] =
        _balances[_account] - _amount;

        _totalSupply =
        _totalSupply - _amount;

        emit Transfer(
            _account,
            address(0x0),
            _amount
        );
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    )
        internal
    {
        _allowances[_owner][_spender] = _amount;

        emit Approval(
            _owner,
            _spender,
            _amount
        );
    }
}

contract DGTownHall is ERC20("External DG", "xDG") {

    DGToken public immutable DG;

    constructor(
        address _tokenAddress
    ) {
        DG = DGToken(
            _tokenAddress
        );
    }

    function stepInside(
        uint256 _DGAmount
    )
        external
    {
        uint256 DGTotal = innerSupply();
        uint256 xDGTotal = totalSupply();

        DGTotal == 0 || xDGTotal == 0
            ? _mint(msg.sender, _DGAmount)
            : _mint(msg.sender, _DGAmount * xDGTotal / DGTotal);

        DG.transferFrom(
            msg.sender,
            address(this),
            _DGAmount
        );
    }

    function stepOutside(
        uint256 _xDGAmount
    )
        external
    {
        uint256 transferAmount = _xDGAmount
            * innerSupply()
            / totalSupply();

        _burn(
            msg.sender,
            _xDGAmount
        );

        DG.transfer(
            msg.sender,
            transferAmount
        );
    }

    function DGAmount(
        address _account
    )
        external
        view
        returns (uint256)
    {
        return balanceOf(_account)
            * innerSupply()
            / totalSupply();
    }

    function outsidAmount(
        uint256 _xDGAmount
    )
        external
        view
        returns (uint256 _DGAmount)
    {
        return _xDGAmount
            * innerSupply()
            / totalSupply();
    }

    function insideAmount(
        uint256 _DGAmount
    )
        external
        view
        returns (uint256 _xDGAmount)
    {
        uint256 xDGTotal = totalSupply();
        uint256 DGTotal = innerSupply();

        return xDGTotal == 0 || DGTotal == 0
            ? _DGAmount
            : _DGAmount * xDGTotal / DGTotal;
    }

    function innerSupply()
        public
        view
        returns (uint256)
    {
        return DG.balanceOf(address(this));
    }
}
