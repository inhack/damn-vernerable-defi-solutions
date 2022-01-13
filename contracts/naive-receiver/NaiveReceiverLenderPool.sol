// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Re-Entracy Attack 방지를 위한 라이브러리
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// address 타입과 관련된 기능 지원을 위한 라이브러리
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NaiveReceiverLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract NaiveReceiverLenderPool is ReentrancyGuard {

    // Address.sol 라이브러리 attach
    using Address for address;

    // FlashLoan 이용을 위한 수수료로 1 ether(저렴한 금액은 아님!)
    uint256 private constant FIXED_FEE = 1 ether; // not the cheapest flash loan

    /**
     * @notice 현재 FlashLoan의 이용수수료 확인을 위한 용도
     * @return constant인 FIXED_FEE 값 반환
     */
    function fixedFee() external pure returns (uint256) {
        return FIXED_FEE;
    }

    /**
     * @notice FlashLoan 기능으로, 대출자에게 원하는 만큼의 토큰을 대출
     * @param borrower 토큰을 대출하려는 대출자로 컨트랙트 형태여야 함(EOA는 안됨)
     * @param borrowAmount 대출하려는 토큰의 개수
     * @dev msg.sender가 borrower인지 검증하는 로직이 없음 -> 공격자가 임의의 사용자의 컨트랙트에 있는 잔고를 고갈시킬 수 있음(수수료 사용)
     */
    function flashLoan(address borrower, uint256 borrowAmount) external nonReentrant {
        // (1) Flash Loan 컨트랙트의 잔액이 borrowAmount에 비해 충분한지 확인
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= borrowAmount, "Not enough ETH in pool");

        // (2) 대출자인 borrower가 컨트랙트인지 확인(not EOA)
        require(borrower.isContract(), "Borrower must be a deployed contract");

        // borrower.receiveEther() 호출
        // Transfer ETH and handle control to receiver
        borrower.functionCallWithValue(
            abi.encodeWithSignature(
                "receiveEther(uint256)",
                FIXED_FEE
            ),
            borrowAmount
        );
        
        require(
            address(this).balance >= balanceBefore + FIXED_FEE,
            "Flash loan hasn't been paid back"
        );
    }

    // Allow deposits of ETH
    receive () external payable {}
}
