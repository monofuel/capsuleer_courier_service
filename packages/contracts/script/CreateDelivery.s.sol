// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ICapsuleerCourierService } from "../src/codegen/world/ICapsuleerCourierService.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

// bytes14 constant CCS_DEPLOYMENT_NAMESPACE = "borp";

contract CreateDelivery is Script {
  function run(address worldAddress) external {
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 playerPrivateKey = vm.envUint("TEST_ACCT_PRIVATE_KEY");
    vm.startBroadcast(playerPrivateKey);

    ICapsuleerCourierService ccs = ICapsuleerCourierService(worldAddress);

    uint256 smartObjectId = 82398705600749149788780878354390488360907551818276746855923935479078566838263;
    uint256 typeId = 77800;
    uint256 itemQuantity = 55;

    ccs.borp2__createDeliveryRequest(smartObjectId, typeId, itemQuantity);
    // console.log("Delivery ID: ", deliveryId);


    vm.stopBroadcast();
  }
}
