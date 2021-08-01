// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DD2Token.sol";
import "./DD2NFT.sol";

contract Farm is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint pendingReward;// Reward but not harvest
        uint256 lastTimeDeposit;
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; 
        uint256 lastRewardBlock;
        uint256 accDd2PerShare; 
    }
    // Additonal reward
    DD2NFT public immutable dd2Nft;
    // The Reward TOKEN!
    DD2Token public immutable dd2;
    // Block number when bonus rewardToken period ends.
    uint256 public dd2TokenPerBlock;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // A record status of LP pool.
    mapping(address => bool) public isAdded;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when dd2 mining starts.
    uint256 public immutable startBlock;
    // Time to hold lp
    uint256 public holdingTime = 3 days;
    // Pelnaty when withdraw soon
    uint public feeWithdraw = 3;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event RewardsHarvested(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        DD2Token _dd2,
        uint256 _dd2TokenPerBlock,
        uint256 _startBlock,
        DD2NFT _dd2Nft
    ) public {
        require(address(_dd2) != address(0) , "Zero address");
        require(address(_dd2Nft) != address(0) , "Zero address");
        dd2 = _dd2;
        dd2TokenPerBlock = _dd2TokenPerBlock;
        startBlock = _startBlock;
        dd2Nft = _dd2Nft;
    }

    modifier validatePoolExist(uint256 _pid) {
        require(_pid < poolInfo.length , "Pool are not exist");
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) external onlyOwner {
        require(!isAdded[address(_lpToken)], "Pool already is added");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accDd2PerShare: 0
            })
        );
        isAdded[address(_lpToken)] = true;
    }

    // Update the given pool's dd2 allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) external onlyOwner validatePoolExist(_pid) {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return time multiplier over the given _from to _to block.
    function timeMultiplier(uint256 _from, uint256 _to)
        public
        pure
        returns (uint256)
    {
        return _to.sub(_from);
    
    }

    //Update number of dd2 per block 
    function setDd2PerBlock(uint256 _dd2PerBlock) external onlyOwner {
        massUpdatePools();
        dd2TokenPerBlock = _dd2PerBlock;
    }

    // View function to see pending dd2 on frontend.
    function pendingDd2(uint256 _pid, address _user)
        external
        view
        validatePoolExist(_pid)
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDd2PerShare = pool.accDd2PerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                timeMultiplier(pool.lastRewardBlock, block.number);
            uint256 dd2Reward =
                multiplier.mul(dd2TokenPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accDd2PerShare = accDd2PerShare.add(
                dd2Reward.mul(1e12).div(lpSupply)
            );
        }
        return user.pendingReward.add(user.amount.mul(accDd2PerShare).div(1e12).sub(user.rewardDebt));
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public validatePoolExist(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = timeMultiplier(pool.lastRewardBlock, block.number);
        uint256 dd2Reward =
            multiplier.mul(dd2TokenPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        pool.accDd2PerShare = pool.accDd2PerShare.add(
            dd2Reward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to dd2 Farm for dd2 allocation.
    function deposit(uint256 _pid, uint256 _amount) public validatePoolExist(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending =
                user.amount.mul(pool.accDd2PerShare).div(1e12).sub(
                    user.rewardDebt
                );
        user.pendingReward = user.pendingReward.add(pending);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accDd2PerShare).div(1e12);
        user.lastTimeDeposit = block.timestamp;
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from Pool.
    function withdraw(uint256 _pid, uint256 _amount)
        external
        validatePoolExist(_pid)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accDd2PerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            user.pendingReward = user.pendingReward.add(pending);
        } 
        user.amount = user.amount.sub(_amount); 
        user.rewardDebt = user.amount.mul(pool.accDd2PerShare).div(1e12);
        if(block.timestamp - user.lastTimeDeposit < holdingTime){
            uint256 fee = _amount.mul(feeWithdraw).div(100);
            _amount = _amount - fee;
            pool.lpToken.safeTransfer(address(this), fee);
        } else {
            dd2Nft.mint(address(msg.sender));
        }
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external validatePoolExist(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    //Harvest proceeds msg.sender
    function harvest(uint256 _pid) public validatePoolExist(_pid) returns(uint256) {
       updatePool(_pid); 
       PoolInfo storage pool = poolInfo[_pid];
       UserInfo storage user = userInfo[_pid][msg.sender];  
       uint256 pendingReward = user.pendingReward;
       uint256 totalPending = 
                            user.amount.mul(pool.accDd2PerShare)
                                        .div(1e12)
                                        .sub(user.rewardDebt)
                                        .add(pendingReward); 
       user.pendingReward = 0;
       if (totalPending > 0) {
            dd2.mint(address(this), totalPending);
            safeDd2Transfer(msg.sender, totalPending); 
        }
        user.rewardDebt = user.amount.mul(pool.accDd2PerShare).div(1e12);
        emit RewardsHarvested(msg.sender, _pid, totalPending);
        return totalPending;
    }

    function safeDd2Transfer(address _to, uint256 _amount) internal {
        uint256 dd2Balance = dd2.balanceOf(address(this));
        if (_amount > dd2Balance) {
            dd2.transfer(_to, dd2Balance);
        } else {
            dd2.transfer(_to, _amount);
        }
    }

}