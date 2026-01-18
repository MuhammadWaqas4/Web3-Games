const axios = require("axios");
require("dotenv").config();

exports.generateRandomString = (length = 20) => {
    const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,.<>?"
    let result = "";
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    return result;
}

exports.getPricesOld = async () => {
    const apikey = process.env.CMC_API_KEY;
    try {
        response = await axios.get('https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest', {
          headers: {
            'X-CMC_PRO_API_KEY': apikey,
          },
          params: {
            symbol: "BTC,ETH,BNB",
            convert: "USD",
          },
        });
      } catch(ex) {
        response = null;
        console.log("ex", ex);
      }

      const btcPrice = response?.data?.data?.BTC?.quote?.USD?.price ? response?.data?.data?.BTC?.quote?.USD?.price : "1"
      const ethPrice = response?.data?.data?.ETH?.quote?.USD?.price ? response?.data?.data?.ETH?.quote?.USD?.price : "1"
      const bnbPrice = response?.data?.data?.BNB?.quote?.USD?.price ? response?.data?.data?.BNB?.quote?.USD?.price : "1"

      console.log("Prices:", btcPrice, ethPrice, bnbPrice);

      const btcScaledPrice = Math.round(btcPrice * 1e8).toString();
      const ethScaledPrice = Math.round(ethPrice * 1e8).toString();
      const bnbScaledPrice = Math.round(bnbPrice * 1e8).toString();
          
    return { btcScaledPrice, ethScaledPrice, bnbScaledPrice };
}

exports.getDrandLatest = async () => {
  let randomnessInt;
    try{
          const response = await axios.get("https://api.drand.sh/public/latest");
          const randomnessHex = response.data.randomness;

          randomnessInt = BigInt('0x' + randomnessHex);
          console.log("drand randomnessInt:::::::::", randomnessInt.toString());
          

          return randomnessInt;
    }catch{
      return randomnessInt = 1;
    }
  }

  let btcPrice = 92562.9557105424
  let ethPrice = 3248.562608189853
  let bnbPrice = 913.8253499275219
  
  exports.getPrices = async () => {
      const apikey = process.env.CMC_API_KEY;

      btcPrice  = randomInRange(92500, 93500);
      ethPrice = randomInRange(3248, 3448);
      bnbPrice  = randomInRange(813, 913);

      console.log("Prices:", btcPrice, ethPrice, bnbPrice);
  
      const btcScaledPrice = Math.round(btcPrice * 1e8).toString();
      const ethScaledPrice = Math.round(ethPrice * 1e8).toString();
      const bnbScaledPrice = Math.round(bnbPrice * 1e8).toString();
            
      return { btcScaledPrice, ethScaledPrice, bnbScaledPrice };
  }
  
    function randomInRange(min, max) {
      return Math.floor(Math.random() * (max - min + 1)) + min;
    }