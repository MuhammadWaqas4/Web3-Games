# Web3-Games
Developing Web3 Games
This repository includes the code base for web3 games.

## How do I get set up?

Open a terminal in your workspace and then type in the following commands to fulfil the setup requirements:

1. `git clone https://github.com/MuhammadWaqas4/Web3-Games.git`
2. `cd Web3-Games`
3. `npm i`

## Deployment

### Setup environment variables

Set the `URL_PRODUCTION` and `PRIVATE_KEY_PRODUCTION` as environment variables for production deployment on your preferred mainnet chain or similarly `URL_STAGING` and `PRIVATE_KEY_STAGING` for staging deployment on your preferred testnet chain. Set the `ETHERSCAN_API_KEY` for multi-chain contract verification on etherscan.<br>
You can achieve this by first creating a file named **.env** at the root of your project. Then copy the contents of the **.env.example** file into your newly created **.env** file. Finally fill in the variables for the aforementioned networks.

- `URL_...`: This is the RPC URL of your chosen network. Most online resources can provide these for free.<br>
- `PRIVATE_KEY_...`: This is the private key of your account<sup>1</sup>.<br>
- `ETHERSCAN_API_KEY`: This is the etherscan api key used for contract verification. You can get these from your account on the relevant block explorer of your chosen network.

[1] ***For deployment on testnet chains, please use a key that does NOT have any real funds associated with it.***

### Run the deployment script

For production deployment, open a terminal at the root of your project then run the following command. This will deploy and setup all relevant contracts on your chosen mainnet chain:

`npm run deploy`

For staging deployment, run the following command. This will deploy and setup all relevant contracts on your chosen testnet:

`npm run deploy-staging`

## Test

Open a terminal at the root of your project. Then run the following command:

`npm run test`

**NOTE:** To get gas reports when testing, set the value of `REPORT_GAS` in the **.env** file to `true`, otherwise leave it undefined or set it to `false`.
