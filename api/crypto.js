const { ethers, BigNumber } = require("ethers");
const Random = require("./utils.js");

exports.generateRandomNumberHash = async () => {

    const min = 100;
    const max = 10000;
  
    const suffix = Random.generateRandomString();
    const timestamp = Math.floor(Date.now() / 1000);

    const prices = await Random.getPrices(); 
    const dRand = await Random.getDrandLatest();

    let randomNumber = Math.floor(Math.random() * 1e12);
    
    const embeddedHashNumber = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "uint256", "uint256", "uint256", "uint256", "uint256"],
      [randomNumber, dRand, prices.btcScaledPrice, prices.ethScaledPrice, prices.bnbScaledPrice, timestamp]
    );

    let hashEncode = ethers.utils.keccak256(embeddedHashNumber);
    const uint256Value = ethers.BigNumber.from(hashEncode);
    randomNumber = uint256Value.toString();

    const range = BigInt(max - min);
    console.log("range:", range);
    
    randomNumber = BigInt(randomNumber) %  range;
    randomNumber = Number(randomNumber) + min;

    const encoded = ethers.utils.defaultAbiCoder.encode(["uint256", "string"], [randomNumber, suffix]);
    const hash = ethers.utils.keccak256(encoded);
    return { randomNumber, suffix, hash };
  };
