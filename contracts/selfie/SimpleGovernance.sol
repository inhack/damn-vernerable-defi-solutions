// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableTokenSnapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SimpleGovernance
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SimpleGovernance {

    using Address for address;
    
    struct GovernanceAction {
        address receiver;       // 작업을 실행할 컨트랙트의 주소
        bytes data;             // 컨트랙트에 전달할 데이터 (ABI?)
        uint256 weiAmount;      // 인자
        uint256 proposedAt;     // 작업이 큐에 적재된 시간(timestamp)
        uint256 executedAt;     // 작업이 실행된 시간(timestamp)
    }
    
    DamnValuableTokenSnapshot public governanceToken;

    mapping(uint256 => GovernanceAction) public actions;
    uint256 private actionCounter;
    uint256 private ACTION_DELAY_IN_SECONDS = 2 days;

    event ActionQueued(uint256 actionId, address indexed caller);
    event ActionExecuted(uint256 actionId, address indexed caller);

    constructor(address governanceTokenAddress) {
        require(governanceTokenAddress != address(0), "Governance token cannot be zero address");
        governanceToken = DamnValuableTokenSnapshot(governanceTokenAddress);
        actionCounter = 1;
    }
    
    /**
     * @notice 거버넌스 큐에 실행할 작업을 적재
     * @param receiver 작업을 실행할 컨트랙트의 주소
     * @param data 작업에 사용할 calldata(함수 이름, 인자 등)
     * @return 큐에 적재된 작업의 식별자(actionId)
     */
    function queueAction(address receiver, bytes calldata data, uint256 weiAmount) external returns (uint256) {
        require(_hasEnoughVotes(msg.sender), "Not enough votes to propose an action");          // 큐에 작업을 추가하기 위해서는 전체 토큰 발행량의 절반 이상을 가지고 있어야 함
        require(receiver != address(this), "Cannot queue actions that affect Governance");      // governance 컨트랙트 내 함수는 실행하지 못함

        uint256 actionId = actionCounter;

        GovernanceAction storage actionToQueue = actions[actionId];
        actionToQueue.receiver = receiver;
        actionToQueue.weiAmount = weiAmount;
        actionToQueue.data = data;
        actionToQueue.proposedAt = block.timestamp;     // 작업이 큐에 적재된 시간(timestamp)

        actionCounter++;

        emit ActionQueued(actionId, msg.sender);
        return actionId;
    }

    /**
     * @notice 거버넌스 큐에 적재된 작업 실행
     * @param actionId 실행할 작업의 식별자(actionId)
     */
    function executeAction(uint256 actionId) external payable {
        // _canBeExecuted()에 의해 (1) 아직 실행된 적이 없고(executedAt==0), (2) 큐에 적재된지 2일 이상이 지난 작업만 실행 가능
        require(_canBeExecuted(actionId), "Cannot execute this action");
        
        GovernanceAction storage actionToExecute = actions[actionId];
        actionToExecute.executedAt = block.timestamp;

        actionToExecute.receiver.functionCallWithValue(
            actionToExecute.data,           // address target
            actionToExecute.weiAmount       // bytes memory data
        );

        emit ActionExecuted(actionId, msg.sender);
    }

    function getActionDelay() public view returns (uint256) {
        return ACTION_DELAY_IN_SECONDS;
    }

    /**
     * @dev an action can only be executed if:
     * 1) it's never been executed before and
     * 2) enough time has passed since it was first proposed
     */
    function _canBeExecuted(uint256 actionId) private view returns (bool) {
        GovernanceAction memory actionToExecute = actions[actionId];
        return (
            actionToExecute.executedAt == 0 &&
            (block.timestamp - actionToExecute.proposedAt >= ACTION_DELAY_IN_SECONDS)
        );
    }
    
    function _hasEnoughVotes(address account) private view returns (bool) {
        uint256 balance = governanceToken.getBalanceAtLastSnapshot(account);
        uint256 halfTotalSupply = governanceToken.getTotalSupplyAtLastSnapshot() / 2;
        return balance > halfTotalSupply;
    }
}
