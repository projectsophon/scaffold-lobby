import type { HardhatRuntimeEnvironment } from "hardhat/types";
import { task } from "hardhat/config";

import * as path from "path";
import * as fs from "fs/promises";

import { CONTRACT_ADDRESS, INIT_ADDRESS } from "@darkforest_eth/contracts";
import DarkForestABI from "@darkforest_eth/contracts/abis/DarkForest.json";
import DFInitializeABI from "@darkforest_eth/contracts/abis/DFInitialize.json";

import { createPlanets } from "../utils/planets";
import { getSelectors, FacetCutAction } from "../utils/diamond";

task("lobby:create", "create a lobby from the command line").setAction(createLobby);

async function createLobby({}, hre: HardhatRuntimeEnvironment): Promise<void> {
  // need to force a compile for tasks
  await hre.run("compile");

  const lobbyConfigPath = path.join(hre.config.paths.root, "lobby.json");
  const lobbyConfig = await fs.readFile(lobbyConfigPath, "utf8");
  const initializers = JSON.parse(lobbyConfig);

  const lobbyAddress = await deployLobbyWithDiamond(initializers, hre);

  await createPlanets(lobbyAddress, initializers, hre);

  const contract = await hre.ethers.getContractAt(DarkForestABI, lobbyAddress);

  const raceInit = await deployRaceInit({}, hre);

  const raceFacet = await deployRaceFacet({}, hre);

  const toCut = [
    {
      facetAddress: raceFacet.address,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors("RaceToCenter", raceFacet),
    },
  ];

  const initAddress = raceInit.address;
  const initFunctionCall = raceInit.interface.encodeFunctionData("init", [
    initializers.ROUND_END,
    initializers.CLAIM_PLANET_COOLDOWN,
  ]);

  const initTx = await contract.diamondCut(toCut, initAddress, initFunctionCall);
  const initReceipt = await initTx.wait();
  if (!initReceipt.status) {
    throw Error(`Diamond cut failed: ${initTx.hash}`);
  }
  console.log("Completed diamond cut");

  const race = await hre.ethers.getContractAt("RaceToCenter", lobbyAddress);
  console.log(await race.claimPlanetCooldown());
}

async function deployLobbyWithDiamond(initializers: unknown, hre: HardhatRuntimeEnvironment) {
  const isDev = hre.network.name === "localhost" || hre.network.name === "hardhat";

  // Were only using one account, getSigners()[0], the deployer. Becomes the ProxyAdmin
  const [deployer] = await hre.ethers.getSigners();

  // TODO: The deployer balance should be checked for production.
  // Need to investigate how much this actually costs.

  const baseURI = isDev ? "http://localhost:8081" : "https://zkga.me";

  const contract = await hre.ethers.getContractAt(DarkForestABI, CONTRACT_ADDRESS);

  const initInterface = hre.ethers.Contract.getInterface(DFInitializeABI);

  const whitelistEnabled = false;
  const artifactBaseURI = "";
  const initAddress = INIT_ADDRESS;
  const initFunctionCall = initInterface.encodeFunctionData("init", [whitelistEnabled, artifactBaseURI, initializers]);

  function waitForCreated(): Promise<string> {
    return new Promise(async (resolve) => {
      contract.on("LobbyCreated", async (ownerAddress, lobbyAddress) => {
        if (deployer.address === ownerAddress) {
          console.log(`Lobby created. Play at ${baseURI}/play/${lobbyAddress}`);
          resolve(lobbyAddress);
        }
      });
    });
  }

  // We setup the event handler before creating the lobby
  const result = waitForCreated();

  const tx = await contract.createLobby(initAddress, initFunctionCall);

  const receipt = await tx.wait();
  if (!receipt.status) {
    throw Error(`Lobby creation failed: ${tx.hash}`);
  }

  const lobbyAddress = await result;

  return lobbyAddress;
}

async function deployRaceInit({}, hre: HardhatRuntimeEnvironment) {
  const factory = await hre.ethers.getContractFactory("RaceInit");
  const contract = await factory.deploy();
  await contract.deployTransaction.wait();
  console.log(`RaceInit deployed to: ${contract.address}`);
  return contract;
}

async function deployRaceFacet({}, hre: HardhatRuntimeEnvironment) {
  const factory = await hre.ethers.getContractFactory("RaceToCenter");
  const contract = await factory.deploy();
  await contract.deployTransaction.wait();
  console.log(`RaceToCenter deployed to: ${contract.address}`);
  return contract;
}
