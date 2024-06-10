// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ICapsuleerCourierService } from "../src/codegen/world/ICapsuleerCourierService.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

bytes14 constant CCS_DEPLOYMENT_NAMESPACE = "borp";

contract ConfigureLikes is Script {
  function run(address worldAddress) external {
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 playerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(playerPrivateKey);

    ICapsuleerCourierService ccs = ICapsuleerCourierService(worldAddress);

    ccs.borp__setLikes(77800, 1); // common ore
    ccs.borp__setLikes(77811, 1); // carbonaceous ore

    vm.stopBroadcast();
  }
}
