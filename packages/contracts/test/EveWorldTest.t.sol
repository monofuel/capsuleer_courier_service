// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import "@eveworld/common-constants/src/constants.sol";
import { EntityRecordTable, EntityRecordTableData } from "@eveworld/world/src/codegen/tables/EntityRecordTable.sol";
import { EntityRecordLib } from "@eveworld/world/src/modules/entity-record/EntityRecordLib.sol";
import { Utils as EntityRecordUtils } from "@eveworld/world/src/modules/entity-record/Utils.sol";
import { DeployableState, DeployableStateData } from "@eveworld/world/src/codegen/tables/DeployableState.sol";
import { State } from "@eveworld/world/src/modules/smart-deployable/types.sol";
import { SmartStorageUnitTest } from "@eveworld/world/test/smart-storage-unit/SmartStorageUnitTest.t.sol";

// test file for world helpers

contract ExtendedSmartStorageUnitTest is SmartStorageUnitTest {
  // SmartStorageUnitTest 'owns' the entity record table, so we need to extend it to add records
  using EntityRecordUtils for bytes14;
  using EntityRecordLib for EntityRecordLib.World;

  function addEntityRecord(uint256 id, uint256 typeId, uint256 level, uint256 quantity, bool isBlueprint) public {
    EntityRecordTable.set(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), id, typeId, level, quantity, isBlueprint);
  }
}

contract EveWorldTest is MudTest {
  using EntityRecordUtils for bytes14;
  using EntityRecordLib for EntityRecordLib.World;

  uint256 deployerPrivateKey;
  IBaseWorld world;
  ExtendedSmartStorageUnitTest ssu;
  EntityRecordLib.World entityRecord;

  function setUp() virtual public override {
    setupWorld();
    setupModules();
    setupTestEntities();
    // setupSSU();
  }

  function getItemId(uint256 typeId) public pure returns (uint256) {
    string memory packed = string(abi.encodePacked("item:devnet-", Strings.toString(typeId)));
    return uint256(keccak256(abi.encodePacked(packed)));
  }

  function setupWorld() public {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    StoreSwitch.setStoreAddress(worldAddress);
    world = IBaseWorld(worldAddress);
    deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    entityRecord = EntityRecordLib.World(world, ENTITY_RECORD_DEPLOYMENT_NAMESPACE);
  }

  
  function setupModules() public {
    // borrow setup from SmartStorageUnit test
    ssu = new ExtendedSmartStorageUnitTest();
    ssu.setUp();
  }

  function setupTestEntities() public {
    ssu.addEntityRecord(getItemId(4235), 4235, 12, 100, true);
    ssu.addEntityRecord(getItemId(4236), 4236, 12, 200, true);
    ssu.addEntityRecord(getItemId(4237), 4237, 12, 150, true);
    ssu.addEntityRecord(getItemId(8235), 8235, 12, 100, true);
    ssu.addEntityRecord(getItemId(8236), 8236, 12, 200, true);
    ssu.addEntityRecord(getItemId(8237), 8237, 12, 150, true);
  }

    function testSetDeployableStateToValid(uint256 smartObjectId) public {
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
}