// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./TrustfulOracle.sol";
import "../DamnValuableNFT.sol";

/**
 * @title Exchange
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Exchange is ReentrancyGuard {

    using Address for address payable;

    DamnValuableNFT public immutable token;
    TrustfulOracle public immutable oracle;

    event TokenBought(address indexed buyer, uint256 tokenId, uint256 price);
    event TokenSold(address indexed seller, uint256 tokenId, uint256 price);

    constructor(address oracleAddress) payable {
        token = new DamnValuableNFT();
        oracle = TrustfulOracle(oracleAddress);
    }

    /**
     * @notice NFT Token을 구매하는 기능을 지원
     * @return tokenId 구매자에게 발행된 NFT Token의 식별자(Identifier)
     */
    function buyOne() external payable nonReentrant returns (uint256) {
        uint256 amountPaidInWei = msg.value;
        require(amountPaidInWei > 0, "Amount paid must be greater than zero");

        // Price should be in [wei / NFT]
        uint256 currentPriceInWei = oracle.getMedianPrice(token.symbol());              // Oracle로부터 해당 토큰의 median(중간) 가격 획득
        require(amountPaidInWei >= currentPriceInWei, "Amount paid is not enough");     // 구매자가 전송한 msg.value(amountPaidInWei)는 median 가격 이상이어야 함

        uint256 tokenId = token.safeMint(msg.sender);                                   // 구매자의 주소로 토큰 발행
        
        payable(msg.sender).sendValue(amountPaidInWei - currentPriceInWei);             // 지불금액에서 토큰의 가격을 뺀 차액(잔돈)을 구매자에게 전송

        emit TokenBought(msg.sender, tokenId, currentPriceInWei);

        return tokenId;
    }

    /**
     * @notice NFT Token을 판매하는 기능을 지원
     * @param tokenId 판매자가 소유하고 있는 판매할 NFT Token의 식별자(Identifier)
     */
    function sellOne(uint256 tokenId) external nonReentrant {
        require(msg.sender == token.ownerOf(tokenId), "Seller must be the owner");                      // tokenId에 매핑되는 NFT Token을 가진 소유자 검증
        require(token.getApproved(tokenId) == address(this), "Seller must have approved transfer");     // NFT Token 전송을 위한 approve() 호출 성공 여부

        // Price should be in [wei / NFT]
        uint256 currentPriceInWei = oracle.getMedianPrice(token.symbol());                  // Oracle로부터 해당 토큰의 median(중간) 가격 획득
        require(address(this).balance >= currentPriceInWei, "Not enough ETH in balance");   // 거래소(Exchange 컨트랙트)에 NFT Token 구매를 위한 충분한 잔액이 있는지 확인

        token.transferFrom(msg.sender, address(this), tokenId);         // 판매자로부터 거래소로 NFT Token 전송
        token.burn(tokenId);                                            // 판매자로부터 구매한 NFT Token 소각
        
        payable(msg.sender).sendValue(currentPriceInWei);               // 판매자에게 판매대금(NFT Token의 가격) 전송/지급

        emit TokenSold(msg.sender, tokenId, currentPriceInWei);
    }

    receive() external payable {}
}
