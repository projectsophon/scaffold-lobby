import type { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  RevealSnarkContractCallArgs,
  SnarkJSProofAndSignals,
  revealSnarkWasmPath,
  revealSnarkZkeyPath,
  buildContractCallArgs,
} from "@darkforest_eth/snarks";
import { mimcHash, perlin, modPBigInt } from "@darkforest_eth/hashing";
import DarkForestABI from "@darkforest_eth/contracts/abis/DarkForest.json";
// @ts-ignore
import * as snarkjs from "snarkjs";

export async function createPlanets(lobbyAddress: string, initializers: any, hre: HardhatRuntimeEnvironment) {
  const contract = await hre.ethers.getContractAt(DarkForestABI, lobbyAddress);

  for (const adminPlanetInfo of initializers.planets) {
    try {
      const location = mimcHash(initializers.PLANETHASH_KEY)(adminPlanetInfo.x, adminPlanetInfo.y).toString();
      const adminPlanetCoords = {
        x: adminPlanetInfo.x,
        y: adminPlanetInfo.y,
      };
      const perlinValue = perlin(adminPlanetCoords, {
        key: initializers.SPACETYPE_KEY,
        scale: initializers.PERLIN_LENGTH_SCALE,
        mirrorX: initializers.PERLIN_MIRROR_X,
        mirrorY: initializers.PERLIN_MIRROR_Y,
        floor: true,
      });

      const createPlanetReceipt = await contract.createPlanet({
        ...adminPlanetInfo,
        location,
        perlin: perlinValue,
      });
      await createPlanetReceipt.wait();
      if (adminPlanetInfo.revealLocation) {
        const pfArgs = await makeRevealProof(
          adminPlanetInfo.x,
          adminPlanetInfo.y,
          initializers.PLANETHASH_KEY,
          initializers.SPACETYPE_KEY,
          initializers.PERLIN_LENGTH_SCALE,
          initializers.PERLIN_MIRROR_X,
          initializers.PERLIN_MIRROR_Y
        );
        const revealPlanetReceipt = await contract.revealLocation(...pfArgs);
        await revealPlanetReceipt.wait();
      }
      console.log(`created admin planet at (${adminPlanetInfo.x}, ${adminPlanetInfo.y})`);
    } catch (e) {
      console.log(`error creating planet at (${adminPlanetInfo.x}, ${adminPlanetInfo.y}):`);
      console.log(e);
    }
  }
}

async function makeRevealProof(
  x: number,
  y: number,
  planetHashKey: number,
  spaceTypeKey: number,
  scale: number,
  mirrorX: boolean,
  mirrorY: boolean
): Promise<RevealSnarkContractCallArgs> {
  const { proof, publicSignals }: SnarkJSProofAndSignals = await snarkjs.groth16.fullProve(
    {
      x: modPBigInt(x).toString(),
      y: modPBigInt(y).toString(),
      PLANETHASH_KEY: planetHashKey.toString(),
      SPACETYPE_KEY: spaceTypeKey.toString(),
      SCALE: scale.toString(),
      xMirror: mirrorX ? "1" : "0",
      yMirror: mirrorY ? "1" : "0",
    },
    revealSnarkWasmPath,
    revealSnarkZkeyPath
  );

  return buildContractCallArgs(proof, publicSignals) as RevealSnarkContractCallArgs;
}
