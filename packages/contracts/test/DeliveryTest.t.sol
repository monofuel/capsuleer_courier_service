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

import { EveWorldTest } from "./EveWorldTest.t.sol";

contract TestCapsuleerCourierService is CapsuleerCourierService {
    // Expose internal functions
    function tAddPlayerLikes(address player, uint256 likes) public {
        addPlayerLikes(player, likes);
    }
}

contract DeliveryTest is EveWorldTest {
  using WorldResourceIdInstance for ResourceId;

  ResourceId CCS_SYSTEM_ID;

  function setUp() public override {
    setupWorld();
    setupCCSWrapper();
    setupModules();
    setupTestEntities();
  }

  function setupCCSWrapper() public {
    // Setup a test CCS wrapper system to replace the existing one
    bytes14 CCS_DEPLOYMENT_NAMESPACE = "borp";
    bytes16 SYSTEM_NAME = bytes16("CapsuleerCourier");
    CCS_SYSTEM_ID =
      ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, CCS_DEPLOYMENT_NAMESPACE, SYSTEM_NAME))));

    vm.startBroadcast(deployerPrivateKey);
    TestCapsuleerCourierService testCCS = new TestCapsuleerCourierService();
    world.registerSystem(CCS_SYSTEM_ID, testCCS, true);
    vm.stopBroadcast();
  }
  
  function testGetItemId(uint16 typeId) public {
    // using int16 because typeID is generally a small number even though it's uint256
    vm.assume(typeId != 0);
    uint256 expectedItemId = getItemId(typeId);

    vm.startBroadcast(deployerPrivateKey);
    bytes memory result = world.call(
      CCS_SYSTEM_ID,
      abi.encodeCall(CapsuleerCourierService.getItemId, (typeId))
    );

    uint256 itemId = abi.decode(result, (uint256));

    assertEq(itemId, expectedItemId);
    vm.stopBroadcast();
  }

  function testSetLikes(uint16 typeId, uint256 amount) public {
    vm.assume(typeId != 0);

    // setLikes requires owner permissions
    vm.startBroadcast(deployerPrivateKey);
    world.call(
      CCS_SYSTEM_ID,
      abi.encodeCall(CapsuleerCourierService.setLikes, (typeId, amount))
    );

    // assert the table is updated
    uint256 itemId = getItemId(typeId);
    uint256 likes = ItemLikes.get(itemId);
    assertEq(likes, amount);

    vm.stopBroadcast();
  }

  function testPlayerLikes(address sender, uint16 addLikes) public {
    // uint16 addLikes to prevent overflow
    vm.assume(sender != address(0));
    vm.assume(addLikes != 0);

    vm.startBroadcast(deployerPrivateKey);
    uint256 existingLikes = PlayerLikes.get(sender);
    vm.stopBroadcast();

    world.call(
      CCS_SYSTEM_ID,
      abi.encodeCall(TestCapsuleerCourierService.tAddPlayerLikes, (sender, addLikes))
    );

    vm.startBroadcast(deployerPrivateKey);
    uint256 updatedLikes = PlayerLikes.get(sender);
    assertEq(updatedLikes, existingLikes + addLikes);
    vm.stopBroadcast();
  }

  function testAddingPlayerLikes(address sender, uint16 addLikes) public {
    vm.assume(sender != address(0));
    vm.assume(addLikes != 0);

    vm.startBroadcast(deployerPrivateKey);
    uint256 existingLikes = PlayerLikes.get(sender);
    vm.stopBroadcast();

    // add likes twice to test that we are adding to existing likes
    world.call(
      CCS_SYSTEM_ID,
      abi.encodeCall(TestCapsuleerCourierService.tAddPlayerLikes, (sender, addLikes))
    );

    vm.startBroadcast(deployerPrivateKey);
    uint256 updatedLikes = PlayerLikes.get(sender);
    assertEq(updatedLikes, existingLikes + addLikes);
    vm.stopBroadcast();

    world.call(
      CCS_SYSTEM_ID,
      abi.encodeCall(TestCapsuleerCourierService.tAddPlayerLikes, (sender, addLikes))
    );


    vm.startBroadcast(deployerPrivateKey);
    uint256 finalLikes = PlayerLikes.get(sender);
    assertEq(finalLikes, existingLikes + addLikes + addLikes);
    vm.stopBroadcast();
  }

  function testRandomItemId() public {

    bytes memory result = world.call(
      CCS_SYSTEM_ID,
      abi.encodeCall(CapsuleerCourierService.newRandomId, ())
    );
    uint256 randomId = abi.decode(result, (uint256));
    console.log("Random ID:", randomId);

  }

  function testGetItemLikes() public {
    uint256 itemId = getItemId(77800);
    uint256 amount = 1;
    vm.startBroadcast(deployerPrivateKey);
    ItemLikes.set(itemId, amount);
    vm.stopBroadcast();

    bytes memory result = world.call(
      CCS_SYSTEM_ID,
      abi.encodeCall(CapsuleerCourierService.getItemLikes, (itemId))
    );

    uint256 likes = abi.decode(result, (uint256));
    assertEq(likes, amount);
  }

  // function testValidatedItemId() public {
  //   uint256 typeId = 77800;
  //   uint256 expectedItemId = getItemId(typeId);

  //   bytes memory result = world.call(
  //     CCS_SYSTEM_ID,
  //     abi.encodeCall(CapsuleerCourierService.getValidatedItemId, (typeId))
  //   );
  //   uint256 itemId = abi.decode(result, (uint256));
  //   assertEq(itemId, expectedItemId);
  // }

  
}