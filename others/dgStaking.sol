// SPDX-License-Identifier: -- 🎲 --

pragma solidity ^0.7.0;

import "./common-contracts/SafeMath.sol";

library Math {

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

contract Context {

    constructor() {}

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this;
        return msg.data;
    }
}

contract Ownable is Context {

    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(isOwner(), 'Ownable: caller is not the owner');
        _;
    }

    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(
            newOwner != address(0x0),
            'Ownable: new owner is the zero address'
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Address {

    function isContract(address account) internal view returns (bool) {

        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }

    function toPayable(address account) internal pure returns (address payable) {
        return address(uint160(account));
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            'Address: insufficient balance'
        );

        (bool success, ) = recipient.call{value: amount}('');
        require(
            success,
            'Address: unable to send value, recipient may have reverted'
        );
    }
}

library SafeERC20 {

    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    )
        internal
    {
        callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.transfer.selector,
                to,
                value
            )
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    )
        internal
    {
        callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.transferFrom.selector,
                from,
                to,
                value
            )
        );
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            'SafeERC20: approve from non-zero to non-zero allowance'
        );

        callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                value
            )
        );
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {

        uint256 newAllowance =
        token.allowance(address(this), spender).add(value);

        callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {

        uint256 newAllowance =
        token.allowance(
            address(this),
            spender
        ).sub(value);

        callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function callOptionalReturn(IERC20 token, bytes memory data) private {

        require(
            address(token).isContract(),
            'SafeERC20: call to non-contract'
        );

        (bool success, bytes memory returndata) = address(token).call(data);

        require(
            success,
            'SafeERC20: low-level call failed'
        );

        if (returndata.length > 0) {
            require(
                abi.decode(returndata, (bool)),
                'SafeERC20: ERC20 operation did not succeed'
            );
        }
    }
}

abstract contract IRewardDistributionRecipient is Ownable {

    address public rewardDistributor;

    modifier onlyRewardDistributor() {
        require(
            _msgSender() == rewardDistributor,
            'dgStaking: wrong sender'
        );
        _;
    }

    function setRewardDistribution(address _rewardDistributor)
        external
        onlyOwner
    {
        rewardDistributor = _rewardDistributor;
    }
}

contract LPTokenWrapper {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public bpt = IERC20(
        0xb27A31f1b0AF2946B7F582768f03239b1eC07c2c
    );

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        bpt.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        bpt.safeTransfer(msg.sender, amount);
    }
}

contract dgStaking is LPTokenWrapper, IRewardDistributionRecipient {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public dg = IERC20(
        0xddaAd340b0f1Ef65169Ae5E41A8b10776a75482d
    );

    uint256 public nextReduction;
    uint256 public constant DURATION = 4 weeks;

    uint256 public rewardIndex;
    uint256[4] public rewardAmounts;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    constructor(uint256 _startIn) {

        lastUpdateTime = block.timestamp + _startIn;
        nextReduction = lastUpdateTime + DURATION;

        rewardAmounts[0] = 17500E18;
        rewardAmounts[1] = 10500E18;
        rewardAmounts[2] = 7350E18;
        rewardAmounts[3] = 3850E18;

        rewardRate = rewardAmounts[0].div(DURATION);
    }

    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    event RewardAdded(
        uint256 reward
    );

    event RewardUpdated(
        uint256 rewardRate,
        uint256 timestamp,
        uint256 nextReduction
    );

    event Staked(
        address indexed user,
        uint256 amount
    );

    event Withdrawn(
        address indexed user,
        uint256 amount
    );

    event RewardPaid(
        address indexed user,
        uint256 reward
    );

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0x0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier updateRewardRate() {
        if (block.timestamp > nextReduction && rewardIndex < 3) {
            rewardIndex++;
            rewardRate = rewardAmounts[rewardIndex].div(DURATION);
            lastUpdateTime = nextReduction;
            nextReduction = lastUpdateTime + DURATION;

            emit RewardUpdated(
                rewardRate,
                lastUpdateTime,
                nextReduction
            );
        }
        _;
    }

    modifier onlyAfterLastReduction {
        require(
            block.timestamp >= nextReduction &&
            rewardIndex == 3,
            'dgStaking: too early'
        );
        _;
    }


    function lastTimeRewardApplicable()
        public
        view
        returns (uint256)
    {
        return block.timestamp > lastUpdateTime
            ? Math.min(
                block.timestamp,
                nextReduction
            ) : lastUpdateTime;

    }

    function rewardPerToken()
        public
        view
        returns (uint256)
    {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored.add(
            lastTimeRewardApplicable()
                .sub(lastUpdateTime)
                .mul(rewardRate)
                .mul(1E18)
                .div(totalSupply())
        );
    }

    function stake(
        uint256 amount
    )
        public
        override
        updateRewardRate
        updateReward(msg.sender)
    {
        require(
            amount > 0,
            'dgStaking: zero stake'
        );
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(
        uint256 amount
    )
        public
        override
        updateRewardRate
        updateReward(msg.sender)
    {
        require(
            amount > 0,
            'dgStaking: zero reward'
        );
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(
            balanceOf(msg.sender)
        );
        getReward();
    }

    function getReward()
        public
        updateRewardRate
        updateReward(msg.sender)
    {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            dg.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function earned(
        address account
    )
        public
        view
        returns (uint256)
    {
        uint256 difference = _difference(account);
        return balanceOf(account)
            .mul(difference)
            .div(1E18)
            .add(rewards[account]);
    }

    function _difference(
        address account
    )
        public
        view
        returns (uint256)
    {
        rewardPerToken().sub(
            userRewardPerTokenPaid[account]
        );
    }

    function extendRewards(
        uint256 _newReward
    )
        external
        onlyRewardDistributor
        onlyAfterLastReduction
    {
        rewardRate = _newReward.div(DURATION);
        lastUpdateTime = nextReduction;
        nextReduction = lastUpdateTime + DURATION;

        emit RewardUpdated(
            rewardRate,
            lastUpdateTime,
            nextReduction
        );
    }

    function withdrawLeftOver(
        uint256 _amount
    )
        external
        onlyRewardDistributor
        onlyAfterLastReduction
    {
        dg.safeTransfer(rewardDistributor, _amount);
    }
}