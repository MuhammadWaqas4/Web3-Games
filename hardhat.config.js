require("@nomicfoundation/hardhat-foundry");
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();
require("hardhat-contract-sizer");
require("hardhat-storage-layout");

/**
 * @type {import("hardhat/config").HardhatUserConfig}
 */
module.exports = {
    solidity: {
        compilers: [
            {
                version: "0.8.30",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 12466
                    },
                    evmVersion: "cancun",
                    viaIR: true
                }
            },
            {
                version: "0.8.19",
                settings: {
                    viaIR: true,
                    optimizer: {
                        enabled: true,
                        runs: 1000000
                    }
                }
            }
        ]
    },
    defaultNetwork: "production",
    networks: {
        hardhat: {
            forking: process.env.HARDHAT_FORK ? { url: process.env.URL_PRODUCTION } : undefined
        },
        production: {
            url: process.env.URL_PRODUCTION || "https://place.holder",
            accounts: [
                process.env.PRIVATE_KEY_PRODUCTION ||
                    "0x0000000000000000000000000000000000000000000000000000000000000000"
            ]
        },
        staging: {
            url: process.env.URL_STAGING || "https://place.holder",
            accounts: [
                process.env.PRIVATE_KEY_STAGING || "0x0000000000000000000000000000000000000000000000000000000000000000"
            ]
        }
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY
    },
    paths: {
        tests: "tests_hardhat"
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS === "true",
        outputFile: "docs/gas-report.txt",
        noColors: true
    },
    contractSizer: {
        unit: "B"
    }
};
