// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { console } from "forge-std/console.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";

import { IERC721 } from "@eveworld/world/src/modules/eve-erc721-puppet/IERC721.sol";
import { InventoryLib } from "@eveworld/world/src/modules/inventory/InventoryLib.sol";
import { InventoryItem } from "@eveworld/world/src/modules/inventory/types.sol";
import { IInventoryErrors } from "@eveworld/world/src/modules/inventory/IInventoryErrors.sol";

import { EntityRecordTable, EntityRecordTableData } from "@eveworld/world/src/codegen/tables/EntityRecordTable.sol";

import { DeployableTokenTable } from "@eveworld/world/src/codegen/tables/DeployableTokenTable.sol";

import { Utils as EntityRecordUtils } from "@eveworld/world/src/modules/entity-record/Utils.sol";
import { Utils as InventoryUtils } from "@eveworld/world/src/modules/inventory/Utils.sol";
import { Utils as SmartDeployableUtils } from "@eveworld/world/src/modules/smart-deployable/Utils.sol";
import "@eveworld/common-constants/src/constants.sol";

import { Deliveries, DeliveriesData } from "../../codegen/tables/Deliveries.sol";
import { ItemLikes } from "../../codegen/tables/ItemLikes.sol";
// import { PlayerLikes } from "../../codegen/tables/PlayerLikes.sol";
import { PlayerMetrics } from "../../codegen/tables/PlayerMetrics.sol";

import { AccessControlLib } from "@latticexyz/world-modules/src/utils/AccessControlLib.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";

import "@openzeppelin/contracts/utils/Strings.sol";


contract CapsuleerCourierService is System {
  using InventoryLib for InventoryLib.World;
  using EntityRecordUtils for bytes14;
  using InventoryUtils for bytes14;
  using SmartDeployableUtils for bytes14;

  // TESTED
  function getItemId(uint256 typeId) public pure returns (uint256) {
    string memory packed = string(abi.encodePacked("item:devnet-", Strings.toString(typeId)));
    return uint256(keccak256(abi.encodePacked(packed)));
  }

  function getValidatedItemId(uint256 typeId) public view returns (uint256) {
    uint256 itemId = getItemId(typeId);
    EntityRecordTableData memory itemEntity = EntityRecordTable.get(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(),
      itemId
    );
    if (itemEntity.recordExists == false) {
      revert IInventoryErrors.Inventory_InvalidItem(
        "CCS: item is not created on-chain",
        itemId
      );
    }
    return itemId;
  }

  // TESTED
  function getItemLikes(uint256 itemId) public view returns (uint256) {
    uint256 likes = ItemLikes.get(itemId);
    if (likes == 0) {
      revert IInventoryErrors.Inventory_InvalidItem(
        "CCS: item type does not have likes associated",
        itemId
      );
    }
    return likes;
  }

  // TESTED
  function newRandomId() public view returns (uint256 randomId) {
    randomId = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
  }

  // TESTED
  function setLikes(uint256 typeId, uint256 amount) public {
    _requireOwner();
    console.log("Setting likes for item:", typeId, " amount:", amount);
    uint256 itemId = getItemId(typeId);
    ItemLikes.set(itemId, amount);
  }

  // TESTED
  function addPlayerLikes(address playerAddress, uint256 amount) internal {
    console.log("Adding likes to player:", playerAddress, " amount:", amount);
    uint256 existingLikes = PlayerMetrics.getLikes(playerAddress);
    console.log("fetched existing likes");
    PlayerMetrics.setLikes(playerAddress, existingLikes + amount);
  }

  function getSSUOwner(uint256 smartObjectId) internal returns (address) {
    return IERC721(DeployableTokenTable.getErc721Address(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.deployableTokenTableId())).ownerOf(
      smartObjectId
    );
  }

  function incrementPendingSupply(address user) internal returns (uint256 pendingSupplyCount) {
    pendingSupplyCount = PlayerMetrics.getPendingSupplyCount(user) + 1;
    PlayerMetrics.setPendingSupplyCount(user, pendingSupplyCount);
  }

  function decrementPendingSupply(address user) internal returns (uint256 pendingSupplyCount) {
    pendingSupplyCount = PlayerMetrics.getPendingSupplyCount(user) - 1;
    PlayerMetrics.setPendingSupplyCount(user, pendingSupplyCount);
  }

  function incrementDeliveriesCompleted(address user) internal returns (uint256 deliveriesCompleted) {
    deliveriesCompleted = PlayerMetrics.getDeliveriesCompleted(user) + 1;
    PlayerMetrics.setDeliveriesCompleted(user, deliveriesCompleted);
  }

  function createDeliveryRequest(
    uint256 smartObjectId,
    uint256 typeId,
    uint256 itemQuantity
  ) public {
    require(itemQuantity > 0, "quantity cannot be 0");
    require(itemQuantity <= 500, "quantity cannot be more than 500");

    uint256 pendingSupplyCount = incrementPendingSupply(_msgSender());
    require(pendingSupplyCount <= 5, "cannot have more than 5 pending supply requests");

    // TODO validate smartObjectId
    uint256 itemId = getValidatedItemId(typeId);
    uint256 likes = getItemLikes(itemId);
    uint256 deliveryId = newRandomId();

    Deliveries.set(
      deliveryId,
      smartObjectId,
      itemId,
      itemQuantity,
      address(0), // sender address is not known until delivery is fulfilled
      _msgSender(), // reciever of the package
      false
    );
  }

  function delivered(
    uint256 deliveryId
  ) public {

    // sender is the person fulfilling the supply request
    incrementDeliveriesCompleted(_msgSender());

    // delivery validation
    DeliveriesData memory delivery = Deliveries.get(deliveryId);
    if (delivery.smartObjectId == 0) {
      revert IInventoryErrors.Inventory_InvalidItem(
        "CCS: delivery does not exist",
        delivery.itemId
      );
    }
    if (delivery.smartObjectId == 0) {
      revert IInventoryErrors.Inventory_InvalidItem(
        "CCS: item type does not match delivery",
        delivery.itemId
      );
    }

    EntityRecordTableData memory itemEntity = EntityRecordTable.get(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(),
      delivery.itemId
    );
    // TODO assert user is not fulfilling their own delivery
    // I removed this for easier testing on hackathon account
    // if (_msgSender() == delivery.receiver) {
    //   revert IInventoryErrors.Inventory_InvalidItem(
    //     "CCS: cannot fulfill your own delivery you doofus",
    //     itemId
    //   );
    // }

    // move item from ephemeral storage to ssu inventory
    InventoryItem[] memory outItems = new InventoryItem[](1);
    outItems[0] = InventoryItem(
      delivery.itemId, // inventoryItemId
      _msgSender(), // sender / supplier
      itemEntity.itemId, // itemId
      itemEntity.typeId, // typeId
      itemEntity.volume, // volume
      delivery.itemQuantity // quantity
    );
    _inventoryLib().ephemeralToInventoryTransfer(delivery.smartObjectId, outItems);


    // Get the number of likes to reward the sender
    uint256 likes = ItemLikes.get(delivery.itemId);
    if (likes == 0) {
      revert IInventoryErrors.Inventory_InvalidItem(
        "CCS: item type does not have likes associated",
        delivery.itemId
      );
    }

    addPlayerLikes(_msgSender(), likes * delivery.itemQuantity);

    Deliveries.setDelivered(deliveryId, true);
    Deliveries.setSender(deliveryId, _msgSender());
  }

  function pickup(
    uint256 deliveryId
  ) public {
    // sender is the receiver picking up delivery
    uint256 pendingSupplyCount = decrementPendingSupply(_msgSender());

    DeliveriesData memory delivery = Deliveries.get(deliveryId);
    if (_msgSender() != delivery.receiver) {
      revert IInventoryErrors.Inventory_InvalidItem(
        "CCS: you may only pickup your own item",
        deliveryId
      );
    }
    EntityRecordTableData memory itemEntity = EntityRecordTable.get(
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.entityRecordTableId(),
      delivery.itemId
    );
    if (itemEntity.recordExists == false) {
      revert IInventoryErrors.Inventory_InvalidItem(
        "CCS: item is not created on-chain",
        delivery.itemId
      );
    }

    address ssuOwner = getSSUOwner(delivery.smartObjectId);
    
    // move the output to the requesting user's inventory
    InventoryItem[] memory outItems = new InventoryItem[](1);
    outItems[0] = InventoryItem(
      delivery.itemId, // inventoryItemId
      ssuOwner, // ssu inventory
      itemEntity.itemId, // itemId
      itemEntity.typeId, // typeId
      itemEntity.volume, // volume
      delivery.itemQuantity // quantity
    );
    _inventoryLib().inventoryToEphemeralTransfer(delivery.smartObjectId, outItems);

    Deliveries.deleteRecord(deliveryId);
  }

  function getLikes() public view returns (uint256) {
    return PlayerMetrics.getLikes(_msgSender());
  }

  function _inventoryLib() internal view returns (InventoryLib.World memory) {
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(FRONTIER_WORLD_DEPLOYMENT_NAMESPACE))) {
      return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE });
    } else return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE });
  }

  function getContractAddress() public view returns (address) {
    return address(this);
  }

  function _requireOwner() internal view {
    AccessControlLib.requireOwner(SystemRegistry.get(address(this)), _msgSender());
  }
}