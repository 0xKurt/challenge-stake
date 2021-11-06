pragma solidity ^0.8.2;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// @title EthStake, contract to stake eth and get reward token in return (10% apr)
// @dev contract inherits from openzeppelin ReentrancyGuard
// @author Kurt Merbeth
contract EthStake is ReentrancyGuard{
    address public owner;
    uint256 public totalStaked = 0;
    uint256 public stakeRewards = 0;
    uint256 public latestRewardTimestamp = 0;
    uint256 internal yearInSec = 31536000;
    bool internal initialized = false;

    IERC20 rewardToken;
    AggregatorV3Interface internal priceFeed;
    
    struct Stake {
       uint256 amount;
       uint256 initStakeReward;
    }
    
    mapping(address => Stake[]) public stakeholder;
    
    // @dev Checks if the msg sender is owner
    modifier onlyOwner() {
        require(msg.sender == owner, 'msg.sender is not owner');
        _;
    }
    
    // @dev Checks if tthe contract is initialized
    modifier isInit() {
        require(initialized,'contract not initialized');
        _;
    }
    
    // @dev Emitted when user deposit to contract
    event Deposited(address indexed from_, uint256 amount_);
    
    // @dev Emitted when user withdraws from contract
    event Withdrawed(address indexed to_, uint256 ethAmount_, uint256 rewardAmount_);
    
    // @notice contructor sets owner to msg.sender
    constructor() {
        owner = msg.sender;
    }
    
    // @notice init should be called after contract creation
    // @params rewardToken_ address of the reward token
    // @params priceFeed_ address of the chainlink priceFeed
    // @params rewardTokenAmount_ amount of rewardToken to deposit to stake contract
    function init(address rewardToken_, address priceFeed_, uint256 rewardTokenAmount_) public onlyOwner {
        if(!initialized) {
            initialized = true;
            rewardToken = IERC20(rewardToken_);
            priceFeed = AggregatorV3Interface(priceFeed_); // rinkeby eth/usd pricefeed: 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
            depositRewardToken(rewardTokenAmount_);
        }
    }
    
    // @notice user send ether to the stake contract for staking. 
    // @dev value should be >= 5 ETH, reward() will be called, value will be added to totalStaked and added to the users stakes
    // @return true
    function deposit() external payable isInit returns(bool) {
        require(msg.value >= 5 ether, 'eth value too low');
        reward();
        Stake memory newStake = Stake(msg.value, stakeRewards);
        stakeholder[msg.sender].push(newStake);
        totalStaked += msg.value;
        
        emit Deposited(msg.sender, msg.value);
        
        return true;
    }
    
    // @notice withdraws the users stake and its reward
    // @dev calls reward(), iterates over users stakes, calculates reward
    // @dev delete user stake data, transfer ether and reward to user
    // @return true
    function withdraw() external nonReentrant isInit returns(bool) {
        require(stakeholder[msg.sender][0].amount > 0, 'sender did not stake any eth');
        reward();
        uint256 rewardToPay = 0;
        uint256 amount = 0;
        for(uint256 i; i < stakeholder[msg.sender].length; i++) {
            Stake memory stake = stakeholder[msg.sender][i];
            rewardToPay += (stake.amount/totalStaked) * (stakeRewards - stake.initStakeReward); 
            amount += stake.amount;
        }
        totalStaked -= amount;
        delete stakeholder[msg.sender];
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed.");
        
        require(rewardToken.balanceOf(address(this)) >= rewardToPay, 'reward token balance too low');
        rewardToken.transfer(msg.sender, rewardToPay); // reward token could be directly minted instead
        
        emit Withdrawed(msg.sender, amount, rewardToPay);
        
        return true;
    }
    
    // @notice updates and calculates reward and sets latest reward() timestamp
    // @notice math: 10%  of  'ether price of total stake'  divided to 'year in seconds'  multiplied to 'seconds passed since the last function call'
    // @dev receive price from chainlink price feed
    // @dev should be called at least once a day by cron task(!)
    function reward() public isInit {
        if(latestRewardTimestamp != 0 && totalStaked > 0) {
            (,int price,,,) = priceFeed.latestRoundData();
            stakeRewards += (((totalStaked/1 ether) * uint(price)) / (10 * yearInSec)) * (block.timestamp - latestRewardTimestamp);
        }
        latestRewardTimestamp = block.timestamp;
    }
    
    // @notice Function to withdraw all deposited reward token
    // @dev only owner
    function withdrawRewardToken(address to) external onlyOwner isInit returns(bool) {
        rewardToken.transfer(to, rewardToken.balanceOf(address(this)));
        
        return true;
    }
    
    // @notice Function to deposit new reward token
    function depositRewardToken(uint256 amount) public isInit returns(bool) {
        require(rewardToken.allowance(msg.sender, address(this)) >= amount,'contract is not allowed to transfer users funds');
        rewardToken.transferFrom(msg.sender, address(this), amount);
        
        return true;
    }
    
    // function emergencyWithdraw() external onlyOwner returns(bool) {
    //     (bool success, ) = msg.sender.call{value: address(this).balance}("");
    //     require(success, "Transfer failed.");
        
    //     return true;
    // }
}