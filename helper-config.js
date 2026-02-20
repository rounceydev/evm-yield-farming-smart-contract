const networkConfig = {
  1337: {
    name: "localhost",
    performanceFee: 2000, // 20% in basis points
    managementFee: 200, // 2% annual in basis points
    withdrawalFee: 0, // No withdrawal fee
  },
  11155111: {
    name: "sepolia",
    performanceFee: 2000,
    managementFee: 200,
    withdrawalFee: 0,
  },
};

const developmentChains = ["hardhat", "localhost"];

module.exports = {
  networkConfig,
  developmentChains,
};
