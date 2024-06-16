// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// TODO this file is being refactored into separate test t.sol files

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
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
import { Utils as SmartDeployableUtils } from "@eveworld/world/src/modules/smart-deployable/Utils.sol";
import { InventoryLib } from "@eveworld/world/src/modules/inventory/InventoryLib.sol";

// EVE World helper test contract

contract EveWorldTest is MudTest {
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

  uint256 deployerPrivateKey;
  bytes14 constant ERC721_DEPLOYABLE = "DeployableTokn";


  function _installModule(IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function setUp() virtual public override {
    setupWorld();
  }

  function setupWorld() public {
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
    deployerPrivateKey = vm.envUint("PRIVATE_KEY");
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


    setupTestEntity(4235, 10);
    setupTestEntity(4236, 20);
    setupTestEntity(4237, 15);
    setupTestEntity(8235, 10);
    setupTestEntity(8236, 20);
    setupTestEntity(8237, 15);
    setupTestEntity(77800, 15);
    setupTestEntity(77811, 15);
  }

  function setupTestEntity(uint256 typeId, uint256 volume) public {
    uint256 itemId = getItemId(typeId);
    EntityRecordTable.set(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), itemId, itemId, typeId, volume, true);
  }

  function getItemId(uint256 typeId) public pure returns (uint256) {
    string memory packed = string(abi.encodePacked("item:devnet-", Strings.toString(typeId)));
    return uint256(keccak256(abi.encodePacked(packed)));
  }

  function testSSU() public {
    // TODO
  }
}
