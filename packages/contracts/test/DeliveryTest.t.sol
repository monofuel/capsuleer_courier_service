// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance }  from "@latticexyz/world/src/WorldResourceId.sol";

import { PlayerLikes } from "../src/codegen/tables/PlayerLikes.sol";
import { ICapsuleerCourierService } from "../src/codegen/world/ICapsuleerCourierService.sol";

import "../src/systems/capsuleer_courier_service/CapsuleerCourierService.sol";

contract TestCapsuleerCourierService is CapsuleerCourierService {
    // Expose internal functions
    function tAddPlayerLikes(address player, uint256 likes) public {
        addPlayerLikes(player, likes);
    }
}

contract DeliveryTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  // ICapsuleerCourierService ccs;
  TestCapsuleerCourierService testCCS;

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    StoreSwitch.setStoreAddress(worldAddress);
    world = IBaseWorld(worldAddress);
    // ccs = ICapsuleerCourierService(worldAddress);
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Setup a test CCS wrapper system to replace the existing one
    bytes14 CCS_DEPLOYMENT_NAMESPACE = "borp";
    bytes16 SYSTEM_NAME = bytes16("CapsuleerCourier");
    ResourceId CCS_SYSTEM_ID =
      ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, CCS_DEPLOYMENT_NAMESPACE, SYSTEM_NAME))));

    testCCS = new TestCapsuleerCourierService();
    // world.registerNamespace(CCS_SYSTEM_ID.getNamespaceId());
    vm.startBroadcast(deployerPrivateKey);

    world.registerSystem(CCS_SYSTEM_ID, testCCS, true);
    
    vm.stopBroadcast();

  }
  
  function testPlayerLikes() public {
    // TODO this does not work  yet, computers are hard
    address sender = address(1337);
    uint256 addLikes = 50;
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // vm.startPrank(sender);
    // vm.startBroadcast(deployerPrivateKey);


    // testCCS.setLikes(77800, 1);

    // testCCS.tAddPlayerLikes(sender, addLikes);

    // vm.stopBroadcast();
  }
}