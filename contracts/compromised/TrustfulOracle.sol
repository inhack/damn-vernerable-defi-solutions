// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/**
 * @title TrustfulOracle
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @notice A price oracle with a number of trusted sources that individually report prices for symbols.
 *         The oracle's price for a given symbol is the median price of the symbol over all sources.
 */
contract TrustfulOracle is AccessControlEnumerable {

    bytes32 public constant TRUSTED_SOURCE_ROLE = keccak256("TRUSTED_SOURCE_ROLE");
    bytes32 public constant INITIALIZER_ROLE = keccak256("INITIALIZER_ROLE");

    // Source address => (symbol => price)
    mapping(address => mapping (string => uint256)) private pricesBySource;

    modifier onlyTrustedSource() {
        require(hasRole(TRUSTED_SOURCE_ROLE, msg.sender));
        _;
    }

    modifier onlyInitializer() {
        require(hasRole(INITIALIZER_ROLE, msg.sender));
        _;
    }

    event UpdatedPrice(
        address indexed source,
        string indexed symbol,
        uint256 oldPrice,
        uint256 newPrice
    );

    constructor(address[] memory sources, bool enableInitialization) {
        require(sources.length > 0);
        for(uint256 i = 0; i < sources.length; i++) {
            _setupRole(TRUSTED_SOURCE_ROLE, sources[i]);
        }

        if (enableInitialization) {
            _setupRole(INITIALIZER_ROLE, msg.sender);
        }
    }

    // A handy utility allowing the deployer to setup initial prices (only once)
    /**
     * @notice NFT Token의 시작가격을 설정하는 기능
     * @param sources 가격을 제시해주는 trusted reporter 주소 배열
     * @param symbols NFT Token의 심볼 배열
     * @param prices 각 토큰별 시작 가격
     * @dev 세 파라미터는 모두 배열로 크기가 같아야 하며, 각 tuststed reporter가 제시한 심볼별 가격을 나타냄
     *      onlyInitializer() 제어자를 통해 INITIALIZER_ROLE이 부여된 계정만 호출 가능
     */
    function setupInitialPrices(
        address[] memory sources,
        string[] memory symbols,
        uint256[] memory prices
    ) 
        public
        onlyInitializer
    {
        // Only allow one (symbol, price) per source
        require(sources.length == symbols.length && symbols.length == prices.length);   // 초기가격 설정 시, 세 파라미터는 배열로 모두 같은 크기여야 함
        for(uint256 i = 0; i < sources.length; i++) {
            _setPrice(sources[i], symbols[i], prices[i]);       // 2중 중첩 mapping(source->symbol->price)인 pricesBySource에 가격 설정
        }
        renounceRole(INITIALIZER_ROLE, msg.sender);         // setupInitialPrices()를 호출한 msg.sender 를 INITIALIZER_ROLE에서 제거(한번만 초기가격 설정이 가능하도록?)
    }

    /**
     * @notice 특정 symbol을 가진 NFT Token에 새로운 가격을 부여하기 위한 기능
     * @param symbol 가격을 설정할 symbol
     * @param newPrice 설정할 새로운 가격
     * @dev _setPrice()를 호출하여 2중 중첩 mapping(source->symbol->price)인 pricesBySource에 가격 설정
     *      onlyTrustedSource() 제어자를 통해 TRUSTED_SOURCE_ROLE이 부여된 계정만 호출 가능
     */
    function postPrice(string calldata symbol, uint256 newPrice) external onlyTrustedSource {
        _setPrice(msg.sender, symbol, newPrice);
    }

    /**
     * @notice _computedMedianPrice()를 호출하여 특정 symbol의 중간 가격 산출
     * @param symbol 중간 가격을 산출할 대상 symbol
     * @return 산출된 중간가격 반환
     */
    function getMedianPrice(string calldata symbol) external view returns (uint256) {       // calldata?
        return _computeMedianPrice(symbol);
    }

    /**
     * @notice 특정 symbol에 설정된 모든 가격 리스트를 반환
     * @param symbol 가격 리스트를 산출할 대상 symbol
     * @return 배열 형태의 가격 리스트
     */
    function getAllPricesForSymbol(string memory symbol) public view returns (uint256[] memory) {
        uint256 numberOfSources = getNumberOfSources();
        uint256[] memory prices = new uint256[](numberOfSources);

        for (uint256 i = 0; i < numberOfSources; i++) {
            address source = getRoleMember(TRUSTED_SOURCE_ROLE, i);
            prices[i] = getPriceBySource(symbol, source);
        }

        return prices;
    }

    /**
     * @notice 특정 Trusted Source가 설정한 symbol의 가격 확인
     */
    function getPriceBySource(string memory symbol, address source) public view returns (uint256) {
        return pricesBySource[source][symbol];
    }

    /**
     * @notice Trusted Source로 등록된 주소의 갯수 확인
     */
    function getNumberOfSources() public view returns (uint256) {
        return getRoleMemberCount(TRUSTED_SOURCE_ROLE);
    }

    function _setPrice(address source, string memory symbol, uint256 newPrice) private {
        uint256 oldPrice = pricesBySource[source][symbol];
        pricesBySource[source][symbol] = newPrice;
        emit UpdatedPrice(source, symbol, oldPrice, newPrice);
    }

    function _computeMedianPrice(string memory symbol) private view returns (uint256) {
        uint256[] memory prices = _sort(getAllPricesForSymbol(symbol));

        // calculate median price
        if (prices.length % 2 == 0) {
            uint256 leftPrice = prices[(prices.length / 2) - 1];
            uint256 rightPrice = prices[prices.length / 2];
            return (leftPrice + rightPrice) / 2;
        } else {
            return prices[prices.length / 2];
        }
    }

    function _sort(uint256[] memory arrayOfNumbers) private pure returns (uint256[] memory) {
        for (uint256 i = 0; i < arrayOfNumbers.length; i++) {
            for (uint256 j = i + 1; j < arrayOfNumbers.length; j++) {
                if (arrayOfNumbers[i] > arrayOfNumbers[j]) {
                    uint256 tmp = arrayOfNumbers[i];
                    arrayOfNumbers[i] = arrayOfNumbers[j];
                    arrayOfNumbers[j] = tmp;
                }
            }
        }        
        return arrayOfNumbers;
    }
}