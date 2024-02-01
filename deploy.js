const HDWalletProvider = require("@truffle/hdwallet-provider");
const { Web3 } = require("web3");
const { abi, evm } = require("./compile");

const provider = new HDWalletProvider(
  "round enough ability stick kick rebuild shaft hour tower medal achieve palace",
  // remember to change this to your own phrase!
  "https://sepolia.infura.io/v3/c03aa10c1f174872971d3540f6a9bef7"
  // remember to change this to your own endpoint!
);

const web3 = new Web3(provider);

const deploy = async () => {
  const accounts = await web3.eth.getAccounts();

  console.log("Attempting to deploy from account", accounts[0]);

  const result = await new web3.eth.Contract(abi)
    .deploy({ data: evm.bytecode.object, arguments: ["0x4c5bC2044c44CcA67a5B6100496C4c570d532D4D"] })
    .send({ gas: "5000000", from: accounts[0] });

  // console.log(JSON.stringify(abi));
  console.log("Contract deployed to", result.options.address);
  provider.engine.stop();
};
deploy();
