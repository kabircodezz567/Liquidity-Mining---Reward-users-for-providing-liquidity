// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title SimpleLiquidityMining
 * @dev A minimalist contract that rewards users for providing liquidity
 */
contract SimpleLiquidityMining {
    
    IERC20 public lpToken;      // LP token users stake
    IERC20 public rewardToken;  // Reward token distributed
    address public owner;
    
    uint256 public rewardRate = 100; // Reward per hour per token staked
    uint256 public totalStaked;
    
    struct UserInfo {
        uint256 stakedAmount;
        uint256 lastStakeTime;
        uint256 pendingRewards;
    }
    
    mapping(address => UserInfo) public users;
    
    event Staked(address user, uint256 amount);
    event Withdrawn(address user, uint256 amount);
    event RewardsClaimed(address user, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(address _lpToken, address _rewardToken) {
        lpToken = IERC20(_lpToken);
        rewardToken = IERC20(_rewardToken);
        owner = msg.sender;
    }
    
    /**
     * @dev Stake LP tokens to start earning rewards
     * @param amount Amount of LP tokens to stake
     */
    function stakeLPTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        
        // Update pending rewards before staking
        _updateRewards(msg.sender);
        
        // Transfer LP tokens from user to contract
        require(lpToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // Update user and global state
        users[msg.sender].stakedAmount += amount;
        users[msg.sender].lastStakeTime = block.timestamp;
        totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    /**
     * @dev Withdraw staked LP tokens
     * @param amount Amount of LP tokens to withdraw
     */
    function withdrawLPTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(users[msg.sender].stakedAmount >= amount, "Insufficient staked amount");
        
        // Update pending rewards before withdrawal
        _updateRewards(msg.sender);
        
        // Update user and global state
        users[msg.sender].stakedAmount -= amount;
        totalStaked -= amount;
        
        // Transfer LP tokens back to user
        require(lpToken.transfer(msg.sender, amount), "Transfer failed");
        
        emit Withdrawn(msg.sender, amount);
    }
    
    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards() external {
        _updateRewards(msg.sender);
        
        uint256 rewards = users[msg.sender].pendingRewards;
        require(rewards > 0, "No rewards to claim");
        
        // Reset pending rewards
        users[msg.sender].pendingRewards = 0;
        
        // Transfer reward tokens to user
        require(rewardToken.transfer(msg.sender, rewards), "Reward transfer failed");
        
        emit RewardsClaimed(msg.sender, rewards);
    }
    
    /**
     * @dev Get pending rewards for a user
     * @param user Address of the user
     * @return Amount of pending rewards
     */
    function getPendingRewards(address user) external view returns (uint256) {
        if (users[user].stakedAmount == 0) {
            return users[user].pendingRewards;
        }
        
        uint256 timeElapsed = block.timestamp - users[user].lastStakeTime;
        uint256 newRewards = (users[user].stakedAmount * rewardRate * timeElapsed) / 3600; // per hour
        
        return users[user].pendingRewards + newRewards;
    }
    
    /**
     * @dev Update reward rate (only owner)
     * @param newRate New reward rate per hour per token
     */
    function updateRewardRate(uint256 newRate) external onlyOwner {
        rewardRate = newRate;
    }
    
    /**
     * @dev Internal function to update user's pending rewards
     */
    function _updateRewards(address user) internal {
        if (users[user].stakedAmount > 0) {
            uint256 timeElapsed = block.timestamp - users[user].lastStakeTime;
            uint256 newRewards = (users[user].stakedAmount * rewardRate * timeElapsed) / 3600;
            users[user].pendingRewards += newRewards;
        }
        users[user].lastStakeTime = block.timestamp;
    }
}
