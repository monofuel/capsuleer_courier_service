// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";

import { PlayerLikes } from "../src/codegen/tables/PlayerLikes.sol";
import { ICapsuleerCourierService } from "../src/codegen/world/ICapsuleerCourierService.sol";

contract DeliveryTest is MudTest {

  IBaseWorld world;
  ICapsuleerCourierService ccs;

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    StoreSwitch.setStoreAddress(worldAddress);
    world = IBaseWorld(worldAddress);
    ccs = ICapsuleerCourierService(worldAddress);

  }
  
  function testPlayerLikes() public {
    address sender = address(3997);
    uint256 addLikes = 50;
    vm.startPrank(sender);

    // uint256 existingLikes = PlayerLikes.get(sender);
    // assertEq(existingLikes, 0);
    // PlayerLikes.set(sender, existingLikes + addLikes);

    // uint256 updatedLikes = PlayerLikes.get(sender);
    // assertEq(updatedLikes, addLikes);

    vm.stopPrank();
  }
}