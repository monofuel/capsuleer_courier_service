
import { createPublicClient, fallback, webSocket, http, custom, createWalletClient, Hex, parseEther, ClientConfig, PublicClientConfig } from "viem";
import { createFaucetService } from "@latticexyz/services/faucet";
import { encodeEntity, syncToRecs } from "@latticexyz/store-sync/recs";
import { syncToZustand } from "@latticexyz/store-sync/zustand";

import { getNetworkConfig } from "./getNetworkConfig";
import { createBurnerAccount, getContract, transportObserver, ContractWrite } from "@latticexyz/common";

import { Subject, share } from "rxjs";

import { world } from "./world";
import { devnetChains, testnetChains } from "@eveworld/chains";

import CustomIWorldAbi from "../../../contracts/out/IWorld.sol/IWorld.abi.json";
import { IWorldAbi as MainWorldAbi, ERC2771ForwarderAbi } from "@eveworld/contracts";
import mudConfig from "../../../contracts/mud.config";

export type SetupNetworkResult = Awaited<ReturnType<typeof setupNetwork>>;

const INDEXER_URL = "https://awakening-indexer.exoplanet-horizons.net";

// This code seems to work OK in chrome, but it is very slow to sync state from the chain
// NB. this code does not appear to work from the in-game browser for some reason. not sure why.
//     `inf: [$evefrontier.ethereum.request] reject({"message":"invalid request","code":-32600})`
// I think I will be standing up my own indexer instead.

export async function setupNetwork() {

  const IWorldAbi = [
    ...CustomIWorldAbi,
    ...MainWorldAbi.abi,
  ]

  const networkConfig = await getNetworkConfig();

  // transport: transportObserver(fallback([webSocket(), http()]) as any),

  // @ts-ignore
  const transport = window.ethereum;

  const clientOptions = {
    chain: networkConfig.chain as any,
    transport: custom(transport),
    pollingInterval: 1000,
  } as const satisfies ClientConfig;

  const publicClient = createPublicClient(clientOptions);

  const burnerAccount = createBurnerAccount(networkConfig.privateKey as Hex);
  const burnerWalletClient = createWalletClient({
    ...clientOptions,
    account: burnerAccount as any,
  });

  const write$ = new Subject<ContractWrite>();

  const worldContract = getContract({
    address: networkConfig.worldAddress as Hex,
    abi: IWorldAbi as any,
    publicClient: publicClient as any,
    walletClient: burnerWalletClient as any,
    onWrite: (write) => write$.next(write),
  });


  // const { components, latestBlock$, storedBlockLogs$, waitForTransaction } = await syncToRecs({
  //   world,
  //   config: mudConfig,
  //   address: networkConfig.worldAddress as Hex,
  //   publicClient: publicClient as any,
  //   startBlock: BigInt(networkConfig.initialBlockNumber),
  // });

  const { tables, useStore, latestBlock$, storedBlockLogs$, waitForTransaction } = await syncToZustand({
    config: mudConfig,
    address: networkConfig.worldAddress as Hex,
    publicClient: publicClient as any,
    startBlock: BigInt(networkConfig.initialBlockNumber),
    indexerUrl: INDEXER_URL,
  });

  if (networkConfig.faucetServiceUrl) {
    const address = burnerAccount.address;
    console.info("[Dev Faucet]: Player address -> ", address);

    const faucet = createFaucetService(networkConfig.faucetServiceUrl);

    const requestDrip = async () => {
      const balance = await publicClient.getBalance({ address });
      console.info(`[Dev Faucet]: Player balance -> ${balance}`);
      const lowBalance = balance < parseEther("1");
      if (lowBalance) {
        console.info("[Dev Faucet]: Balance is low, dripping funds to player");
        // Double drip
        await faucet.dripDev({ address });
        await faucet.dripDev({ address });
      }
    };

    requestDrip();
    // Request a drip every 20 seconds
    setInterval(requestDrip, 20000);
  }

  return {
    world,
    // components,
    playerEntity: encodeEntity({ address: "address" }, { address: burnerWalletClient.account.address }),
    tables,
    useStore,
    publicClient,
    latestBlock$,
    storedBlockLogs$,
    waitForTransaction,
    worldContract,
    write$: write$.asObservable().pipe(share()),
  }
}