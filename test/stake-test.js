const { expect } = require("chai")
const { ethers } = require("hardhat");
const { utils } = require("ethers");

describe("Eth Stake Contract", function () {

  let rewardToken, tokenFactory;
  let priceFeed, priceFeedFactory;
  let ethStake, ethStakeFactory;
  let owner, wallet1, wallet2;

  beforeEach(async () => {
    [owner, wallet1, wallet2, _] = await ethers.getSigners();

    tokenFactory = await ethers.getContractFactory('StandardToken');
    rewardToken = await tokenFactory.deploy('devUSD', 'devUSD', 100000000000000, '8');

    priceFeedFactory = await ethers.getContractFactory('PriceFeedDummy');
    priceFeed = await priceFeedFactory.deploy();

    ethStakeFactory = await ethers.getContractFactory('EthStake');
    ethStake = await ethStakeFactory.deploy();

    await rewardToken.approve(ethStake.address, 50000000000000);
    await ethStake.init(rewardToken.address, priceFeed.address, 50000000000000);
  })

  describe('Deployment', () => {
    it('should have the correct owner', async () => {
      expect(await ethStake.getOwner()).to.equal(owner.address);
    });
    it('should have the correct rewardToken balance at owners wallet', async () => {
      expect(await rewardToken.balanceOf(owner.address)).to.equal(50000000000000);
    });
    it('should have the correct reward balance at eth stake contract', async () => {
      expect(await rewardToken.balanceOf(ethStake.address)).to.equal(50000000000000);
    });
    it('latestRewardTimestamp should be zero', async () => {
      expect(await ethStake.latestRewardTimestamp()).to.equal(0);
    });
    it('stakeRewards should be zero', async () => {
      expect(await ethStake.stakeRewards()).to.equal(0);
    });
    it('totalStaked should be zero', async () => {
      expect(await ethStake.totalStaked()).to.equal(0);
    });
  })

  describe('No-Deposit Contract Interaction', () => {
    it('should fail to deposit with less than 5 ETH', async () => {
      await expect(ethStake.connect(wallet1).deposit({ value: ethers.utils.parseEther("1") })).to.be.revertedWith('eth value too low')
    })
    it('should fail to withdraw with no deposit', async () => {
      await expect(ethStake.connect(wallet1).withdraw()).to.be.revertedWith('sender did not stake any eth')
    })
  })

  describe('Deposit Contract Interaction', () => {
    beforeEach(async () => {
      await ethStake.connect(wallet1).deposit({ value: ethers.utils.parseEther("5") })
    })
    it('should deposit 5 ETH', async () => {
      expect(await ethStake.totalStaked()).to.equal(ethers.utils.parseEther("5"));
    });
    it('latestRewardTimestamp should be greater than zero', async () => {
      expect(await ethStake.latestRewardTimestamp()).to.be.above(0);
    });
    it('should be able to withdraw', async () => {
      await ethStake.connect(wallet1).withdraw()
      expect(await ethStake.totalStaked()).to.equal(0);
    });

    //to be continued...

  })



})