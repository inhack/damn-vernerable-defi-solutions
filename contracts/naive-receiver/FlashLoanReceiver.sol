// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// address 타입과 관련된 기능 지원을 위한 라이브러리
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title FlashLoanReceiver
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @notice NaiveReceiverLenderPool 대출풀을 이용하기 위해 사용자가 배포하는 컨트랙트
 */
contract FlashLoanReceiver {
    using Address for address payable;

    address payable private pool;

    /**
     * @notice 생성자, LendingPool의 주소 초기화
     * @param poolAddress LendingPool 주소
     */
    constructor(address payable poolAddress) {
        pool = poolAddress;
    }

    /**
     * @notice Flash Loan LendingPool이 호출하는 함수로 receiver로부터 대출금 및 fee 지불
     * @param fee 대출풀에 지불하는 거래수수료(1 ETH)
     */
    // Function called by the pool during flash loan
    function receiveEther(uint256 fee) public payable {
        // (1) receiveEther()를 호출한 어카운트가 pool(LendingPool)인지 확인
        require(msg.sender == pool, "Sender must be pool");

        // LendingPool에 반환할 금액(amountToBeReapid) 계산 = 전송한 ETH + fee(Fixed Fee: 1 ETH)
        uint256 amountToBeRepaid = msg.value + fee;

        // (2) Receiver 컨트랙트의 잔고가 반환할 금액에 비해 충분한지 확인
        require(address(this).balance >= amountToBeRepaid, "Cannot borrow that much");
        
        // 아무동작도 하지 않는 함수이지만, 제대로 구현된다면 대출금을 이용해 사용자가 할 작업들이 구현되어야 함
        _executeActionDuringFlashLoan();
        
        // 대출 금액과 수수료를 Lending Pool에 반환
        // Return funds to pool
        pool.sendValue(amountToBeRepaid);
    }

    // Internal function where the funds received are used
    function _executeActionDuringFlashLoan() internal { }

    // Allow deposits of ETH
    receive () external payable {}
}