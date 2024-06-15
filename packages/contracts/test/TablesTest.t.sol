// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";

import { ItemLikes } from "../src/codegen/tables/ItemLikes.sol";
import { PlayerLikes } from "../src/codegen/tables/PlayerLikes.sol";
import { ICapsuleerCourierService } from "../src/codegen/world/ICapsuleerCourierService.sol";

// Test working directly with our tables

contract TableTest is MudTest {

  uint256 deployerPrivateKey;

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    StoreSwitch.setStoreAddress(worldAddress);

    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
  }

  function getItemId(uint256 typeId) public pure returns (uint256) {
    string memory packed = string(abi.encodePacked("item:devnet-", Strings.toString(typeId)));
    return uint256(keccak256(abi.encodePacked(packed)));
  }

  function testSetItemLikes() public {
    uint256 itemId = getItemId(77800);
    uint256 amount = 1;
    vm.startBroadcast(deployerPrivateKey);
    
    ItemLikes.set(itemId, amount);

    vm.stopBroadcast();
  }

  function testSetPlayerLikes() public {
    address sender = address(1337);
    uint256 addLikes = 50;

    vm.startBroadcast(deployerPrivateKey);
    uint256 existingLikes = PlayerLikes.get(sender);
    assertEq(existingLikes, 0);
    PlayerLikes.set(sender, existingLikes + addLikes);

    uint256 updatedLikes = PlayerLikes.get(sender);
    assertEq(updatedLikes, addLikes);
    vm.stopBroadcast();
  }
}