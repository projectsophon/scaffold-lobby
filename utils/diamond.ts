import type { utils } from "ethers";

export const enum FacetCutAction {
  Add = 0,
  Replace = 1,
  Remove = 2,
}

interface HasInterface {
  interface: utils.Interface;
}

const signaturesToIgnore: readonly [string, string][] = [
  // The SolidState contracts adds a `supportsInterface` function,
  // but we already provide that function through DiamondLoupeFacet
  // ['DFArtifactFacet$', 'supportsInterface(bytes4)'],
] as const;

function isIncluded(contractName: string, signature: string): boolean {
  const isIgnored = signaturesToIgnore.some(([contractNameMatcher, ignoredSignature]) => {
    if (contractName.match(contractNameMatcher)) {
      return signature === ignoredSignature;
    } else {
      return false;
    }
  });

  return !isIgnored;
}

function getSignatures(contract: HasInterface): string[] {
  return Object.keys(contract.interface.functions);
}

function getSelector(contract: HasInterface, signature: string): string {
  return contract.interface.getSighash(signature);
}

export function getSelectors(contractName: string, contract: HasInterface): string[] {
  const signatures = getSignatures(contract);
  const selectors: string[] = [];

  for (const signature of signatures) {
    if (isIncluded(contractName, signature)) {
      selectors.push(getSelector(contract, signature));
      // this.changes.added.push([contractName, signature]);
    }
  }

  return selectors;
}
