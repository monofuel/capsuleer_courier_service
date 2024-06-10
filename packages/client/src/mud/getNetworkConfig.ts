/*
 * Network specific configuration for the client.
 * By default connect to the anvil test network.
 *
 */

/*
 * By default the template just creates a temporary wallet
 * (called a burner wallet) and uses a faucet (on our test net)
 * to get ETH for it.
 *
 * See https://mud.dev/tutorials/minimal/deploy#wallet-managed-address
 * for how to use the user's own address instead.
 */
import { getBurnerPrivateKey } from "@latticexyz/common";
import { MUDChain, latticeTestnet, mudFoundry } from "@latticexyz/common/chains";

/*
 * Import the addresses of the World, possibly on multiple chains,
 * from packages/contracts/worlds.json. When the contracts package
 * deploys a new `World`, it updates this file.
 */
import worlds from "../../../contracts/worlds.json";

/*
 * The supported chains.
 * By default, there are only two chains here:
 *
 * - mudFoundry, the chain running on anvil that pnpm dev
 *   starts by default. It is similar to the viem anvil chain
 *   (see https://viem.sh/docs/clients/test.html), but with the
 *   basefee set to zero to avoid transaction fees.
 * - latticeTestnet, our public test network.
 *
 * See https://mud.dev/tutorials/minimal/deploy#run-the-user-interface
 * for instructions on how to add networks.
 */
import { devnetChains, testnetChains } from "@eveworld/chains";
import { supportedChains } from "./supportedChains";

// import chain  from "../../../../blockchain-config.json";

export async function getNetworkConfig() {
  const params = new URLSearchParams(window.location.search);

  const chain = testnetChains[0];

  console.log("chainID", chain.id.toString());


  /*
   * Get the address of the World. If you want to use a
   * different address than the one in worlds.json,
   * provide it as worldAddress in the query string.
   */
  const world = worlds[chain.id.toString()];
  const worldAddress = params.get("worldAddress") || world?.address;
  if (!worldAddress) {
    throw new Error(`No world address found for chain ${chain.id}. Did you run \`mud deploy\`?`);
  }
  console.log("worldAddress", worldAddress);

  /*
   * MUD clients use events to synchronize the database, meaning
   * they need to look as far back as when the World was started.
   * The block number for the World start can be specified either
   * on the URL (as initialBlockNumber) or in the worlds.json
   * file. If neither has it, it starts at the first block, zero.
   */
  const initialBlockNumber = params.has("initialBlockNumber")
    ? Number(params.get("initialBlockNumber"))
    : world?.blockNumber ?? 0n;

  return {
    privateKey: getBurnerPrivateKey(),
    chainId: chain.id,
    chain: chain,
    faucetServiceUrl: params.get("faucet") ?? "",
    worldAddress,
    initialBlockNumber,
  };
}
