// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";

import { Deliveries, DeliveriesData } from "../src/codegen/tables/Deliveries.sol";
import { ItemLikes } from "../src/codegen/tables/ItemLikes.sol";
// import { TestIncrementTable } from "../src/codegen/tables/TestIncrementTable.sol";
import { PlayerLikes } from "../src/codegen/tables/PlayerLikes.sol";
import { PlayerMetrics } from "../src/codegen/tables/PlayerMetrics.sol";
import { ICapsuleerCourierService } from "../src/codegen/world/ICapsuleerCourierService.sol";

// Test working directly with our tables

contract TableTest is MudTest {

  uint256 deployerPrivateKey;

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    StoreSwitch.setStoreAddress(worldAddress);

    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
  }

  // uses only 430 gas!! wow
  function testRandomId() public view returns (uint256 randomId) {
    randomId = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
  }

  // uses about 48672 gas
  // function testIncrementalId() public returns (uint256 incId) {
  //   vm.startBroadcast(deployerPrivateKey);
  //   incId = TestIncrementTable.getValue() + 1;
  //   TestIncrementTable.setValue(incId);
  //   vm.stopBroadcast();
  // }

  function getItemId(uint256 typeId) public pure returns (uint256) {
    string memory packed = string(abi.encodePacked("item:devnet-", Strings.toString(typeId)));
    return uint256(keccak256(abi.encodePacked(packed)));
  }

  function testSetCommonOreLikes() public {
    uint256 itemId = getItemId(77800);
    assertEq(54949089622078329307676094148632864879426651785510047822079265544250486580483, itemId);
    uint256 amount = 1;
    vm.startBroadcast(deployerPrivateKey);
    
    ItemLikes.set(itemId, amount);
    uint256 likes = ItemLikes.get(itemId);
    assertEq(likes, amount);

    vm.stopBroadcast();
  }

    function testSetCarbonaceousOreLikes() public {
    uint256 itemId = getItemId(77811);
    assertEq(9540969374646031328134197690309428632894452754236413416084198707556493884019, itemId);
    uint256 amount = 1;
    vm.startBroadcast(deployerPrivateKey);
    
    ItemLikes.set(itemId, amount);
    uint256 likes = ItemLikes.get(itemId);
    assertEq(likes, amount);

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

    PlayerLikes.set(sender, updatedLikes + addLikes);
    updatedLikes = PlayerLikes.get(sender);
    assertEq(updatedLikes, addLikes * 2);
    vm.stopBroadcast();
  }

  function testCreateDeliveryRequest() public returns (uint256 deliveryId) {
    uint256 smartObjectId = 123;
    uint256 typeId = 77800;
    uint256 itemQuantity = 10;
    address receiver = address(1337);
    deliveryId = testRandomId();

    uint256 itemId = getItemId(typeId);

    vm.startBroadcast(deployerPrivateKey);
    Deliveries.set(
      deliveryId,
      smartObjectId,
      itemId,
      itemQuantity,
      address(0), // sender address is not known until delivery is fulfilled
      receiver,
      false
    );

    DeliveriesData memory delivery = Deliveries.get(deliveryId);
    assertEq(delivery.sender, address(0)); // should be 0 until delivery is fulfilled
    assertEq(delivery.receiver, address(1337));
    assertEq(delivery.itemQuantity, 10);
    assertEq(delivery.delivered, false);
    vm.stopBroadcast();
  }

  function testDelivered() public returns (uint256 deliveryId) {
    address sender = address(4337);
    deliveryId = testCreateDeliveryRequest();

    vm.startBroadcast(deployerPrivateKey);
    Deliveries.setDelivered(deliveryId, true);
    Deliveries.setSender(deliveryId, sender);

    DeliveriesData memory delivery = Deliveries.get(deliveryId);
    assertEq(delivery.delivered, true);
    assertEq(delivery.sender, sender);
    assertEq(delivery.receiver, address(1337));
    assertEq(delivery.itemQuantity, 10);

    vm.stopBroadcast();
  }

  function testPickup() public {
    uint256 deliveryId = testDelivered();

    vm.startBroadcast(deployerPrivateKey);

    Deliveries.deleteRecord(deliveryId);

    // Delivery should be zeroed out
    DeliveriesData memory delivery = Deliveries.get(deliveryId);
    assertEq(delivery.delivered, false);
    assertEq(delivery.sender, address(0));
    assertEq(delivery.receiver, address(0));
    assertEq(delivery.itemQuantity, 0);
    assertEq(delivery.smartObjectId, 0);
    assertEq(delivery.itemId, 0);

    vm.stopBroadcast();
  }

}