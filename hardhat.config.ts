import type { HardhatUserConfig } from "hardhat/types";

import "@nomiclabs/hardhat-ethers";
import "./tasks/lobby";

const config: HardhatUserConfig = {
  solidity: "0.8.10",
};

export default config;
