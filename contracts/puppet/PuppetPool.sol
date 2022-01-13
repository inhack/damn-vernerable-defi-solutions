// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";

/**
 * @title PuppetPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract PuppetPool is ReentrancyGuard {

    using Address for address payable;

    mapping(address => uint256) public deposits;
    address public immutable uniswapPair;
    DamnValuableToken public immutable token;
    
    event Borrowed(address indexed account, uint256 depositRequired, uint256 borrowAmount);

    constructor (address tokenAddress, address uniswapPairAddress) {
        token = DamnValuableToken(tokenAddress);
        uniswapPair = uniswapPairAddress;
    }

    // Allows borrowing `borrowAmount` of tokens by first depositing two times their value in ETH
    /**
     * @notice 사용자가 요청한 만큼의 DTV 토큰을 대출해주는 기능으로, 상응하는 ETH 토큰(DTV*2)를 예치해야 함
     * @param borrowAmount 대출할 DTV 토큰의 양
     * @dev msg.value 를 통해 담보로 예치할 ETH 전송
     */
    function borrow(uint256 borrowAmount) public payable nonReentrant {
        uint256 depositRequired = calculateDepositRequired(borrowAmount);
        
        require(msg.value >= depositRequired, "Not depositing enough collateral");
        
        if (msg.value > depositRequired) {
            payable(msg.sender).sendValue(msg.value - depositRequired);
        }

        deposits[msg.sender] = deposits[msg.sender] + depositRequired;

        // Fails if the pool doesn't have enough tokens in liquidity
        require(token.transfer(msg.sender, borrowAmount), "Transfer failed");

        emit Borrowed(msg.sender, depositRequired, borrowAmount);
    }

    /**
     * @notice DTV를 대출해주기 위해 담보로 받을 ETH 수량을 계산
     * @param amount 기준 DTV 토큰의 양 (담보로 예치할 ETH를 계산 목적)
     * @return
     * @dev _computeOraclePrice()를 통해 계산
     */
    function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        return amount * _computeOraclePrice() * 2 / 10 ** 18;
    }

    /**
     * @notice 
     */
    function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair); // uniswapPair ETH 수량과 DTV 토큰 수량의 비율로 계산
    }

     /**
     ... functions to deposit, redeem, repay, calculate interest, and so on ...
     */

}
