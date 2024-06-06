import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'hardhat-tracer';
import "./scripts/deploy";

const TEST_HDWALLET = {
  mnemonic: "test test test test test test test test test test test junk",
  path: "m/44'/60'/0'/0",
  initialIndex: 0,
  count: 20,
  passphrase: "",
};

const PRIVATE_KEY = process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : TEST_HDWALLET;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24"
  },
  networks: {
    'sapphire-localnet': {
      url: "http://localhost:8545",
      accounts: PRIVATE_KEY,
      chainId: 0x5afd,
    },
    'sapphire-localnet-proxy': {
      url: "http://localhost:3001",
      accounts: PRIVATE_KEY,
      chainId: 0x5afd,
    },
    'sapphire-testnet': {
      url: 'https://testnet.sapphire.oasis.io',
      chainId: 0x5aff,
      accounts: PRIVATE_KEY,
    },
    'sapphire-testnet-proxy': {
      url: 'http://localhost:3001',
      chainId: 0x5aff,
      accounts: PRIVATE_KEY,
    },
  }
};

export default config;
