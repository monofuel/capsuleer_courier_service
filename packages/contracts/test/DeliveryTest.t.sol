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
  ResourceId CCS_SYSTEM_ID;
  uint256 deployerPrivateKey;

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    StoreSwitch.setStoreAddress(worldAddress);
    world = IBaseWorld(worldAddress);
    deployerPrivateKey = vm.envUint("PRIVATE_KEY");

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

  function getItemId(uint256 typeId) public pure returns (uint256) {
    string memory packed = string(abi.encodePacked("item:devnet-", Strings.toString(typeId)));
    return uint256(keccak256(abi.encodePacked(packed)));
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

  function testPlayerLikes(address sender, uint256 addLikes) public {
    vm.assume(sender != address(0));
    vm.assume(addLikes != 0);

    world.call(
      CCS_SYSTEM_ID,
      abi.encodeCall(TestCapsuleerCourierService.tAddPlayerLikes, (sender, addLikes))
    );

    // TODO assert likes are set
  }
}