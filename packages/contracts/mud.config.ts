import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  namespace: "borp",
  systems: {
    CapsuleerCourierService: {
      name: "CapsuleerCourierService",
      openAccess: true,
    }
  },
  tables: {
    // TODO populate table with values
    ItemLikes: {
      keySchema: {
        itemId: "uint256",
      },
      valueSchema: {
        likes: "uint256",
      }
    },
    Deliveries: {
      keySchema: {
        deliveryId: "uint256",
      },
      valueSchema: {
        smartObjectId: "uint256",
        itemId: "uint256",
        itemQuantity: "uint256",
        sender: "address",
        receiver: "address",
        delivered: "bool", // false is not delivered, true is delivered, rows are deleted after pickup
      }
    },
    PlayerLikes: {
      keySchema: {
        playerAddress: "address",
      },
      valueSchema: {
        likes: "uint256",
      }
    },
    PlayerMetrics: {
      keySchema: {
        playerAddress: "address",
      },
      valueSchema: {
        likes: "uint256",
        deliveriesCompleted: "uint256",
        pendingSupplyCount: "uint256",
      }
    }
  }
});
