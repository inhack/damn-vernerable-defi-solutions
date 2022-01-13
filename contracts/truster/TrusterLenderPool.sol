// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TrusterLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract TrusterLenderPool is ReentrancyGuard {

    using Address for address;

    IERC20 public immutable damnValuableToken;

    constructor (address tokenAddress) {
        damnValuableToken = IERC20(tokenAddress);
    }

    /**
     * @notice flashLoan 기능을 제공하는 함수로, 사용자에게 원하는 만큼의 토큰을 대출
     * @param borrowAmount 대출할 토큰의 수량
     * @param borrower 대출을 요청한 사용자의 주소
     * @param target 대출 실행 이후, 실행할 함수를 포함하고 있는 컨트랙트의 주소
     * @param data 대출 실행 이후, 실행할 함수와 관련된 데이터(인코딩된 함수이름,인자 등)
     */
    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    )
        external
        nonReentrant
    {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        damnValuableToken.transfer(borrower, borrowAmount);
        target.functionCall(data);      // Vulnerable : target 및 data를 이용해 함수 호출 -> 어떠한 함수든 호출이 가능한 상황

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

}
