// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ICapsuleerCourierService } from "../src/codegen/world/ICapsuleerCourierService.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

// bytes14 constant CCS_DEPLOYMENT_NAMESPACE = "borp";

contract ConfigureLikes is Script {
  function run(address worldAddress) external {
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 playerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(playerPrivateKey);

    ICapsuleerCourierService ccs = ICapsuleerCourierService(worldAddress);

  // - Carbonaceous Materials
  //   - 77804
  // - Iron-Nickel Metals
  //   - 77801
  // - light Metals
  //   - 77802
  // - Osmium
  //   - 78424
  // - Precious Metals and Elements
  //   - 77805
  // - Silicates
  //   - 77803
  // - Sophrogon
  //   - 77728
  // - Thorium
  //   - 78425
  // - Water Ice
  //   - 78423
  // - EU-40 Fuel
  //   - 78516
  // - HAK-55 Fuel
  //   - 79458
  // - usof-30 fuel
  //   - 77818
  // - salt
  //   - 83839

    // ccs.borp__setLikes(77800, 1); // common ore
    // ccs.borp__setLikes(77811, 1); // carbonaceous ore

    uint24[15] memory itemIds = [77804, 77801, 77802, 78424, 77805, 77803, 77728, 78425, 78423, 78516, 79458, 77818, 83839, 77800, 77811];

    // Loop through each item ID and call the setLikes function
    for (uint i = 0; i < itemIds.length; i++) {
        ccs.borp2__setLikes(itemIds[i], 1);
    }

    vm.stopBroadcast();
  }
}
