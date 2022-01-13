// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool {
    using Address for address payable;

    mapping (address => uint256) private balances;

    // ETH deposit(예치) 기능 제공
    // Vulnerable : ETH 수신 여부와 상관없이 balance를 증가시킴
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    // ETH withdraw(인출) 기능 제공
    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw);
    }

    /**
     * @notice Flash Loan 기능으로 사용자에게 원하는 만큼의 ETH를 대출
     * @param amount 대출할 ETH의 수량
     * @dev 대출을 요청한 사용자 컨트랙트의 execute() 함수를 호출 -> execute
     */
    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require(address(this).balance >= balanceBefore, "Flash loan hasn't been paid back");        
    }
}
 