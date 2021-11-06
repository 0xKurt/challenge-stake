pragma solidity 0.8.2;

// for local testing only
contract PriceFeedDummy {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (
            1,
            400000000000, //$4000
            block.timestamp,
            block.timestamp,
            1
        );
    }
}