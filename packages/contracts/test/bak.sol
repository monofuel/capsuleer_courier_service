// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// TODO this file is being refactored into separate test t.sol files

import "forge-std/Test.sol";
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { getKeysWithValue } from "@latticexyz/world-modules/src/modules/keyswithvalue/getKeysWithValue.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { SmartStorageUnitLib } from "@eveworld/world/src/modules/smart-storage-unit/SmartStorageUnitLib.sol";
import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "@eveworld/world/src/modules/smart-storage-unit/types.sol";
import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";
import { EntityRecordTable, EntityRecordTableData } from "@eveworld/world/src/codegen/tables/EntityRecordTable.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";
import { EntityRecordModule } from "@eveworld/world/src/modules/entity-record/EntityRecordModule.sol";
import { IWorld } from "../src/codegen/world/IWorld.sol";
import { Utils as EntityRecordUtils } from "@eveworld/world/src/modules/entity-record/Utils.sol";
import "@eveworld/common-constants/src/constants.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { StaticDataModule } from "@eveworld/world/src/modules/static-data/StaticDataModule.sol";
import { LocationModule } from "@eveworld/world/src/modules/location/LocationModule.sol";
import { StaticDataGlobalTableData } from "@eveworld/world/src/codegen/tables/StaticDataGlobalTable.sol";
import { SmartDeployableModule } from "@eveworld/world/src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployableLib } from "@eveworld/world/src/modules/smart-deployable/SmartDeployableLib.sol";
import { SmartDeployable } from "@eveworld/world/src/modules/smart-deployable/systems/SmartDeployable.sol";
import { InventoryModule } from "@eveworld/world/src/modules/inventory/InventoryModule.sol";
import { Inventory } from "@eveworld/world/src/modules/inventory/systems/Inventory.sol";
import { EphemeralInventory } from "@eveworld/world/src/modules/inventory/systems/EphemeralInventory.sol";
import { InventoryInteract } from "@eveworld/world/src/modules/inventory/systems/InventoryInteract.sol";
import { registerERC721 } from "@eveworld/world/src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "@eveworld/world/src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { Utils } from "@eveworld/world/src/modules/inventory/Utils.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { SmartStorageUnitModule } from "@eveworld/world/src/modules/smart-storage-unit/SmartStorageUnitModule.sol";
import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { DeployableState, DeployableStateData } from "@eveworld/world/src/codegen/tables/DeployableState.sol";
import { State } from "@eveworld/world/src/modules/smart-deployable/types.sol";


import "../src/systems/capsuleer_courier_service/CapsuleerCourierService.sol";
import { Deliveries, DeliveriesData } from "../src/codegen/tables/Deliveries.sol";
import { ICapsuleerCourierService } from "../src/codegen/world/ICapsuleerCourierService.sol";

bytes14 constant CCS_DEPLOYMENT_NAMESPACE = "borp";


// TODO refactor this tests into a reasonable structure, probably with helper functions
// This file is a total mess just to setup all the SSU inventory stuff
// TODO fix these tests to run properly
// for some reason they stopped working for me when I changed function signatures? very weird.
// I could try to separating the logic in capsuleerCourierService system to make it easier to test CCS logic separate from world logic

contract DeliveryTest is MudTest {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using WorldResourceIdInstance for ResourceId;
  using InventoryLib for InventoryLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;
  uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));

  IBaseWorld world;
  IERC721Mintable erc721DeployableToken;
  InventoryLib.World ephemeralInventory;
  SmartDeployableLib.World smartDeployable;
  InventoryModule inventoryModule;

  bytes14 constant ERC721_DEPLOYABLE = "DeployableTokn";


  function _installModule(IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function setUp() public override {
    // mud test passes in this WORLD_ADDRESS env var that it deployed to
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    StoreSwitch.setStoreAddress(worldAddress);
    world = IBaseWorld(worldAddress);


    // install module dependancies
    _installModule(new PuppetModule(), 0);
    _installModule(new StaticDataModule(), STATIC_DATA_DEPLOYMENT_NAMESPACE);
    _installModule(new EntityRecordModule(), ENTITY_RECORD_DEPLOYMENT_NAMESPACE);
    _installModule(new LocationModule(), LOCATION_DEPLOYMENT_NAMESPACE);
    _installModule(new SmartStorageUnitModule(), SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE);

    erc721DeployableToken = registerERC721(
      world,
      ERC721_DEPLOYABLE,
      StaticDataGlobalTableData({ name: "SmartDeployable", symbol: "SD", baseURI: "" })
    );
    // install SmartDeployableModule
    SmartDeployableModule deployableModule = new SmartDeployableModule();
    if (
      NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE)) ==
      address(this)
    )
      world.transferOwnership(
        WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE),
        address(deployableModule)
      );
    world.installModule(deployableModule, abi.encode(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, new SmartDeployable()));
    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    smartDeployable.registerDeployableToken(address(erc721DeployableToken));
    smartDeployable.globalResume();

    // Inventory Module installation
    inventoryModule = new InventoryModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(INVENTORY_DEPLOYMENT_NAMESPACE)) == address(this))
      world.transferOwnership(
        WorldResourceIdLib.encodeNamespace(INVENTORY_DEPLOYMENT_NAMESPACE),
        address(inventoryModule)
      );

    world.installModule(
      inventoryModule,
      abi.encode(INVENTORY_DEPLOYMENT_NAMESPACE, new Inventory(), new EphemeralInventory(), new InventoryInteract())
    );

    ephemeralInventory = InventoryLib.World(world, INVENTORY_DEPLOYMENT_NAMESPACE);


    // deploy an SSU as a user
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address player = vm.addr(deployerPrivateKey);

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    SmartStorageUnitLib.World memory smartStorageUnit = SmartStorageUnitLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE
    });

    smartStorageUnit.createAndAnchorSmartStorageUnit(
      smartObjectId,
      EntityRecordData({ typeId: 7888, itemId: 111, volume: 10 }),
      SmartObjectData({ owner: player, tokenURI: "test" }),
      WorldPosition({ solarSystemId: 1, position: Coord({ x: 1, y: 1, z: 1 }) }),
      1e18, // fuelUnitVolume,
      1, // fuelConsumptionPerMinute,
      1000000 * 1e18, //fuelMaxCapacity,
      100000000, // storageCapacity,
      100000000000 // ephemeralStorageCapacity
    );
    vm.stopBroadcast();

    EntityRecordTable.set(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), 104235, 4235, 12, 100, true);
    EntityRecordTable.set(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), 104236, 4236, 12, 200, true);
    EntityRecordTable.set(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), 104237, 4237, 12, 150, true);
    EntityRecordTable.set(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), 108235, 8235, 12, 100, true);
    EntityRecordTable.set(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), 108236, 8236, 12, 200, true);
    EntityRecordTable.set(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), 108237, 8237, 12, 150, true);

  }

  function baktestSetDeployableStateToValid() public {
    vm.assume(smartObjectId != 0);

    DeployableState.set(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId,
      DeployableStateData({
        createdAt: block.timestamp,
        previousState: State.ANCHORED,
        currentState: State.ONLINE,
        isValid: true,
        anchoredAt: block.timestamp,
        updatedBlockNumber: block.number,
        updatedBlockTime: block.timestamp
      })
    );
  }

  function baktestCreateDeliveryRequest() public {
    address sender = address(99);
    address receiver = address(101);

    // address ccsAddress = ICapsuleerCourierService(worldAddress).borp__getContractAddress();

    ICapsuleerCourierService ccs = ICapsuleerCourierService(worldAddress);

    uint256 typeId = 77800;
    uint256 itemQuantity = 100;
    uint256 itemlikes = 5;
    uint256 itemId = uint256(keccak256(abi.encodePacked("item:devnet-77800")));
    uint256 entityId = itemId;

    console.log(itemId);

    // setup our fake item
    EntityRecordTable.set(ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), entityId, itemId, typeId, 1, true);

    bytes16 SYSTEM_NAME = bytes16("CapsuleerCourier");
    ResourceId CCS_SYSTEM_ID =
      ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, CCS_DEPLOYMENT_NAMESPACE, SYSTEM_NAME))));

    // Set likes for our mock item
    ccs.borp2__setLikes(typeId, itemlikes);

    // create a delivery for our item
    vm.startPrank(receiver);
    // bytes memory data = 
    // world.call(
    //   CCS_SYSTEM_ID,
    //   abi.encodeCall(CapsuleerCourierService.createDeliveryRequest, (smartObjectId, typeId, itemQuantity))
    // );
    ccs.borp2__createDeliveryRequest(smartObjectId, typeId, itemQuantity);
    // uint256 deliveryId = ccs.borp__createDeliveryRequest(smartObjectId, typeId, itemQuantity);
    // uint256 deliveryId = abi.decode(data, (uint256));
    vm.stopPrank();

    uint256 deliveryId = 1;

    DeliveriesData memory delivery = Deliveries.get(deliveryId);

    assertEq(delivery.smartObjectId, smartObjectId, "smartObjectId should be correct");
    

    assertEq(delivery.sender, address(0), "sender should not be set yet");
    assertEq(delivery.receiver, receiver, "receiver should be correct");
    assertEq(delivery.itemId, itemId, "itemId should be correct");
    assertEq(delivery.itemQuantity, itemQuantity, "itemQuantity should be correct");

    // check likes

    // assertEq(l.totalSupply(), 0, "total supply should start 0");
    // assertEq(l.balanceOf(delivery.receiver), 0, "balance of receiver should start 0");
    // assertEq(l.balanceOf(delivery.sender), 0, "balance of sender should start 0");


    // insert item to the ephemeral storage table
    baktestSetDeployableStateToValid();

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(entityId, sender, itemId, typeId, 1, itemQuantity);
    ephemeralInventory.depositToEphemeralInventory(smartObjectId, sender, items);

    vm.startPrank(sender);
    ccs.borp2__delivered(deliveryId);
    vm.stopPrank();

    delivery = Deliveries.get(deliveryId);

    assertEq(delivery.sender, sender, "sender should be set now");
    assertEq(delivery.receiver, receiver, "receiver should be correct");

    // assertEq(delivery.sender, other, "sender should be correct");
    assertEq(delivery.itemId, itemId, "itemId should be correct");
    assertEq(delivery.itemQuantity, itemQuantity, "itemQuantity should be correct");
    assertEq(delivery.delivered, true, "delivered should be correct");

    // check likes
    // assertEq(l.totalSupply(), 50500, "total supply should now be increased");
    // assertEq(l.balanceOf(delivery.receiver), 0, "balance of receiver should start 0");
    // assertEq(l.balanceOf(delivery.sender), 50500, "balance of sender should now be increased");
    
    // pickup the delivery
    vm.startPrank(receiver);
    ccs.borp2__pickup(deliveryId);
    vm.stopPrank();

    delivery = Deliveries.get(deliveryId);
    assertEq(delivery.smartObjectId, 0, "delivery should be deleted");

    // TODO validate ephemeral inventory

  }
}
