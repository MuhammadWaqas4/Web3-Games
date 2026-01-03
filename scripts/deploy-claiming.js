const hre = require("hardhat");

const envfile = require("envfile");
const fs = require("fs");
const parsedENVFile = envfile.parse(fs.readFileSync(".env"));

async function main() {
    // Checking gas price.
    const gasPriceUpperBound = process.env.GAS_PRICE_UPPER_BOUND;
    await checkGasPrice(gasPriceUpperBound);

    // Getting network name.
    const networkName = hre.network.name;
    console.log("Chain:", networkName);

    // Conditional variables.
    const isStaging = networkName === "staging" || networkName === "hardhat";

    // Deployment variables.
    const ownerAddress = ""; // admin wallet
    const linkAddress = ""; // link token address
    const nodeAddress = ""; // node wallet address

    // Deployment variables.
    const assetAddress = process.env.ASSET_ADDRESS;
    const reservoirAddress = "";
 
    const claimingAddress = await deploy("Claiming", [assetAddress, reservoirAddress]);
 
    // Waiting for block explorer.
    await new Promise((resolve) => setTimeout(resolve, 45000));
 
    // Verifying contract.
    await verify(claimingAddress, [assetAddress, reservoirAddress]);
 
    // Setup.
    const reservoirInstance = await hre.ethers.getContractAt("Reservoir", reservoirAddress);
 
    const updateClaimingTransaction = await reservoirInstance.updateClaiming(claimingAddress);
    await updateClaimingTransaction.wait();
 
    console.log("Claiming setup complete");
 
    // Exiting.
    process.exit();
}

async function checkGasPrice(gasPriceUpperBound) {
    let feeData = await hre.ethers.provider.getFeeData();
    let gasPrice = parseFloat(hre.ethers.formatUnits(feeData.gasPrice, "gwei"));
    console.log("Gas Price:", gasPrice, "Gwei");

    if (gasPriceUpperBound != "" && gasPriceUpperBound != "0") {
        while (gasPrice > gasPriceUpperBound) {
            feeData = await hre.ethers.provider.getFeeData();

            if (gasPrice != hre.ethers.formatUnits(feeData.gasPrice, "gwei")) {
                gasPrice = parseFloat(hre.ethers.formatUnits(feeData.gasPrice, "gwei"));
                console.log("Gas Price:", gasPrice, "Gwei");
            }
        }
    }
}

async function deploy(contractName, constructorArguments) {
    const contract = await hre.ethers.deployContract(contractName, constructorArguments);
    await contract.waitForDeployment();

    const contractAddress = contract.target;
    const deploymentTxHash = await contract.deploymentTransaction().hash;
    const deploymentTx = await hre.ethers.provider.getTransactionReceipt(deploymentTxHash);
    const deploymentBlockNumber = deploymentTx.blockNumber;

    console.log(`${contractName} deployed to:`, contractAddress);
    console.log("at block number:", deploymentBlockNumber);

    return contractAddress;
}

async function deployProxy(contractName, initializerArguments, initializerFunction) {
    const contractFactory = await hre.ethers.getContractFactory(contractName);
    const proxy = await hre.upgrades.deployProxy(contractFactory, initializerArguments, {
        initializer: initializerFunction,
        kind: "transparent"
    });
    await proxy.waitForDeployment();

    const proxyAddress = proxy.target;
    const deploymentTxHash = await proxy.deploymentTransaction().hash;
    const deploymentTx = await hre.ethers.provider.getTransactionReceipt(deploymentTxHash);
    const deploymentBlockNumber = deploymentTx.blockNumber;
    const proxyAdminAddress = await hre.upgrades.erc1967.getAdminAddress(proxyAddress);
    const implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(proxyAddress);

    console.log(`${contractName} Proxy deployed to:`, proxyAddress);
    console.log("at block number:", deploymentBlockNumber);
    console.log(`${contractName} ProxyAdmin:`, proxyAdminAddress);
    console.log(`${contractName} Implementation:`, implementationAddress);

    return {
        proxyAddress: proxyAddress,
        proxyAdminAddress: proxyAdminAddress,
        implementationAddress: implementationAddress
    };
}

async function verify(contractAddress, constructorArguments) {
    console.log(`verify ${contractAddress} with arguments ${constructorArguments.join(",")}`);

    try {
        await hre.run("verify:verify", { address: contractAddress, constructorArguments: constructorArguments });
    } catch (error) {
        console.log(error);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
    process.exit();
});
