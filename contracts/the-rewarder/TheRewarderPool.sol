// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./RewardToken.sol";
import "../DamnValuableToken.sol";
import "./AccountingToken.sol";

/**
 * @title TheRewarderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)

 */
contract TheRewarderPool {

    // 토큰 보상을 지급하는 라운드간 시간주기(5일마다 지급)
    // Minimum duration of each round of rewards in seconds
    uint256 private constant REWARDS_ROUND_MIN_DURATION = 5 days;

    // 최근 토큰 보상 지급과 관련된 리워드 메타데이터
    uint256 public lastSnapshotIdForRewards;        // 토큰보상 라운드 식별자
    uint256 public lastRecordedSnapshotTimestamp;   // 토큰보상 라운드 타임스탬프

    // 어카운트별 보상지급 시기(타임스탬프)
    mapping(address => uint256) public lastRewardTimestamps;

    // Token deposited into the pool by users
    DamnValuableToken public immutable liquidityToken;

    // 
    // Token used for internal accounting and snapshots
    // Pegged 1:1 with the liquidity token
    AccountingToken public accToken;
    
    // Token in which rewards are issued
    RewardToken public immutable rewardToken;

    // Track number of rounds
    uint256 public roundNumber;

    /**
     * @notice 리워드풀 생성자로 liquidityToken(DTV) / accToken(AccountingToken) / rewardToken(RewardToken) 초기화 후, 리워드 메타데이터 업데이트
     * @param tokenAddress 토큰 컨트랙트 주소(DTV)
     */
    constructor(address tokenAddress) {
        // Assuming all three tokens have 18 decimals
        liquidityToken = DamnValuableToken(tokenAddress);
        accToken = new AccountingToken();
        rewardToken = new RewardToken();

        _recordSnapshot();
    }

    /**
     * @notice sender must have approved `amountToDeposit` liquidity tokens in advance
     * @param amountToDeposit 리워드를 받기위해 deposit할 토큰의 수
     * @dev 각 사용자가 예치한 토큰은 AccountToken에서 관리하며, 해당 계정 deposit한 수만큼 AccountToken에서 mint() 발행 후, 토큰을 전송받음 (각 사용자가 deposit 전에 approve() 호출 필요)
     */
    function deposit(uint256 amountToDeposit) external {
        require(amountToDeposit > 0, "Must deposit tokens");
        
        accToken.mint(msg.sender, amountToDeposit);
        // AccountToke 발행 직후에, 보상 지급 및 분배
        distributeRewards();

        require(
            liquidityToken.transferFrom(msg.sender, address(this), amountToDeposit)
        );
    }

    /**
     * @notice 
     * @param amountToWithdraw 인출 및 반환할 사용자가 예치했던 토큰의 수
     * @dev 각 어카운트가 예치한 토큰을 관리하고 있는 AccountToken에서 withdraw한 수만큼 burn() 소각 후, 인출한 토큰 전송
     */
    function withdraw(uint256 amountToWithdraw) external {
        accToken.burn(msg.sender, amountToWithdraw);
        require(liquidityToken.transfer(msg.sender, amountToWithdraw));
    }

    /**
     * @notice 토큰을 예치한 사용자들에게 리워드를 분배하는 함수
     * @return uint256 rewards 리워드 토큰 수
     */
    function distributeRewards() public returns (uint256) {
        uint256 rewards = 0;

        // 새로운 보상 라운드일 경우, Snapshot ID 및 Timestamp 갱신 + 라운드 횟수 증가
        // 새로운 보상 라운드인지는 어떻게 확인? 트랜잭션이 포함된 블록의 timestamp가 이전 라운드의 최신 Timestamp보다 5 day 이상인 경우!
        if(isNewRewardsRound()) {
            _recordSnapshot();
        }        
        
        uint256 totalDeposits = accToken.totalSupplyAt(lastSnapshotIdForRewards);
        uint256 amountDeposited = accToken.balanceOfAt(msg.sender, lastSnapshotIdForRewards);

        if (amountDeposited > 0 && totalDeposits > 0) {
            // 라운드당 총 100개의 리워드토큰 발행 (총 Deposit 대비 개인별 Deposit 비율대로 지급)
            rewards = (amountDeposited * 100 * 10 ** 18) / totalDeposits;

            // 리워드 지급 및 리워드 지급 시기 갱신
            if(rewards > 0 && !_hasRetrievedReward(msg.sender)) {
                rewardToken.mint(msg.sender, rewards);
                lastRewardTimestamps[msg.sender] = block.timestamp;
            }
        }

        return rewards;     
    }

    function _recordSnapshot() private {
        lastSnapshotIdForRewards = accToken.snapshot();
        lastRecordedSnapshotTimestamp = block.timestamp;
        roundNumber++;
    }

    function _hasRetrievedReward(address account) private view returns (bool) {
        return (
            lastRewardTimestamps[account] >= lastRecordedSnapshotTimestamp &&
            lastRewardTimestamps[account] <= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION
        );
    }

    function isNewRewardsRound() public view returns (bool) {
        return block.timestamp >= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION;
    }
}
