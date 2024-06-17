import { useState, useContext, useRef, useEffect } from "react";
import { useLocation } from 'react-router-dom';
import { useEntityQuery } from "@latticexyz/react";

import {
  SmartObjectContext,
  FeedbackContext,
  WalletContext,
  WorldContext,
} from "@eveworld/contexts";

import { Actions, Severity, State } from "@eveworld/types";

import { SetupNetworkResult } from "../mud/setupNetwork";
import { useTypes, TypeMap, useCharacters, useDeployables } from '../gateway';
import { Has, HasValue, getComponentValueStrict } from "@latticexyz/recs";

interface Deliveries {
  deliveryId: string;
  smartObjectId: string;
  typeId: string;
  itemId: string;
  itemQuantity: number;
  sender: string;
  receiver: string;
  delivered: boolean;
}


interface DeliverItemOpts {
  deliveryId: BigInt;
}

interface PickupItemOpts {
  deliveryId: BigInt;
}

interface PlayerMetrics {
  key: {
    playerAddress: string;
  },
  value: {
    likes: BigInt;
    deliveriesCompleted: BigInt;
    pendingSupplyCount: BigInt;
  };
}

interface CreateDeliveryOpts {
  smartObjectId: string;
  typeId: string;
  itemQuantity: number;
}

interface CreateDeliveryProps {
  network: SetupNetworkResult;
  smartObjectId: string;
  typeMap: TypeMap;
  submitDisabled: boolean;
  createDeliveryCallback?: (opts: CreateDeliveryOpts) => void;
}

function CreateDelivery({ network, submitDisabled, typeMap, smartObjectId, createDeliveryCallback }: CreateDeliveryProps) {
  // minimal container for input to create a delivery
  // we want to pull smartObjectId from the url query param
  // we want to ask them for a typeId to pick
  // const [smartObjectId, setSmartObjectId] = useState('');
  const [typeId, setTypeId] = useState('77800');
  const [itemQuantity, setItemQuantity] = useState(1);

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    createDeliveryCallback?.({ smartObjectId, typeId, itemQuantity: Number(itemQuantity) });
    setTypeId('77800');
    setItemQuantity(1);
  };

  // TODO fetch image

  // TODO this should be obtained from the list of items with likes configured
  const typeIdWhitelist = ["77800", "77811"];

  return (
    <div className="exo-create-delivery">
      <h1>Item Request Form</h1>
      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column' }}>
        
        {/* <label style={{ display: 'flex', flexDirection: 'row', alignItems: 'center', marginBottom: '10px', width: '25em', justifyContent: 'space-between' }}>
          Smart Object ID:
          <input
          style={{
            backgroundColor: "hsla(26, 85%, 18%, 0.5)"
          }}
          type="text" value={smartObjectId} onChange={e => setSmartObjectId(e.target.value)} />
        </label> */}
        <label style={{ display: 'flex', flexDirection: 'row', alignItems: 'center', marginBottom: '10px', width: '25em', justifyContent: 'space-between' }}>
          Item Type:
          {/* <select // SELECT LIST IS BROKEN IN BROWSER 
            style={{
              backgroundColor: "hsla(26, 85%, 18%, 0.5)",
              width: "15em"
            }}
            value={typeId} 
            onChange={e => setTypeId(e.target.value)}
          >
            {Object.entries(typeMap)
            .filter(([typeId, type]) => typeIdWhitelist.includes(typeId))
              .map(([typeId, type]) => (
              <option key={typeId} value={typeId}>
                {type.name}
              </option>
            ))}
          </select> */}
          <input 
            list="types" 
            id="typeInput"
            style={{
              backgroundColor: "hsla(26, 85%, 18%, 0.5)",
              width: "15em"
            }}
            value={typeId} /* TODO should display item name, not typeId */
            onInput={e => setTypeId((e.target as HTMLInputElement).value)}
          />

          <datalist id="types">
            {Object.entries(typeMap)
              .filter(([typeId, type]) => typeIdWhitelist.includes(typeId))
              .map(([typeId, type]) => (
              <option key={typeId} value={typeId}>
                {type.name}
              </option>
            ))}
          </datalist>

        </label>
        <label style={{ display: 'flex', flexDirection: 'row', alignItems: 'center', marginBottom: '10px', width: '25em', justifyContent: 'space-between' }}>
          Item Quantity:
          <input
          style={{
            width: "5em",
            backgroundColor: "hsla(26, 85%, 18%, 0.5)"
          }}type="number" min="1" max="500" value={itemQuantity} onChange={e => setItemQuantity(Number(e.target.value))} />
        </label>
        <button disabled={submitDisabled} className="primary primary-sm" type="submit">Submit</button>
      </form>
    </div>
  );
}

interface DeliveriesProps {
  network: SetupNetworkResult;
}

export default function Deliveries({ network }: DeliveriesProps) {

  const world = network.world;

  const typeResp = useTypes();
  const types = typeResp.types;
  const items = typeResp.items;

  const charResp = useCharacters();
  const characters = charResp.characters;

  const deployableResp = useDeployables();
  const deployables = deployableResp.deployables;

  const loading = typeResp.loading || charResp.loading || deployableResp.loading;
  const error = typeResp.error || charResp.error || deployableResp.error;

  if (error) {
    console.error(error);
    return <div>Error: {error.message}</div>;
  }

  const location = useLocation();
  const queryParams = new URLSearchParams(location.search);
  const smartObjectId = queryParams.get('smartObjectId');

  const { handleSendTx, handleOpenToast } = useContext(FeedbackContext);
  const { walletClient, publicClient } = useContext(WalletContext);

  const [submitDisabled, setSubmitDisabled] = useState(false);


  const deliveries = network.useStore(state => Object.values(state.getRecords(network.tables.Deliveries)));
  (window as any).deliveries = deliveries;

  const playerMetrics = network.useStore(state => Object.values(state.getRecords(network.tables.PlayerMetrics)));
  (window as any).playerMetrics = playerMetrics;

  const itemLikes = network.useStore(state => Object.values(state.getRecords(network.tables.ItemLikes)));
  (window as any).itemLikes = itemLikes;

  var thisPlayerMetrics: PlayerMetrics | null = null;
  for (const m of playerMetrics) {
    const walletAddr = walletClient?.account?.address;
    if (walletAddr && m.key.playerAddress.toLowerCase() === walletAddr.toLowerCase()) {
      thisPlayerMetrics = m;
    }
  }

  const createCallback = async (opts: CreateDeliveryOpts) => {
    if (!world || !publicClient || !walletClient?.account) {
      console.error("No world or publicClient");
      return;
    }
    console.log("CREATING DELIVERY ORDER");
    console.log(opts);
    setSubmitDisabled(true);
    try {

      const txRequest = await publicClient.simulateContract({
        ...network.worldContract,
        functionName: "borp2__createDeliveryRequest",
        args: [
          BigInt(opts.smartObjectId),
          BigInt(opts.typeId),
          BigInt(opts.itemQuantity),
        ],
        account: walletClient.account.address
      });
      
      handleSendTx(txRequest.request, () => {
        console.log("Delivery order created");
        handleOpenToast(
          Severity.Success,
          undefined,
          "Delivery Order Requested"
        );
      });
    } catch(e) {
      handleOpenToast(
        Severity.Error,
        undefined,
        "Transaction failed to execute"
      );
      console.error(e);
    }

    setSubmitDisabled(false);
  }

  const deliverCallback = async(opts: DeliverItemOpts) => {
    if (!world || !publicClient || !walletClient?.account) {
      console.error("No world or publicClient");
      return;
    }
    console.log("DELIVER CALLBACK");
    console.log(opts);
    try {

      const txRequest = await publicClient.simulateContract({
        ...network.worldContract,
        functionName: "borp2__delivered",
        args: [
          opts.deliveryId,
        ] as any,
        account: walletClient.account.address
      });
      
      handleSendTx(txRequest.request, () => {
        console.log("Item Delivered");
        handleOpenToast(
          Severity.Success,
          undefined,
          "Delivery Order Fulfilled"
        );
      });
    } catch(e) {
      handleOpenToast(
        Severity.Error,
        undefined,
        "Transaction failed to execute"
      );
      console.error(e);
    }

  }

  const pickupCallback = async(opts: DeliverItemOpts) => {
    console.log("PICKUP", opts);

    if (!world || !publicClient || !walletClient?.account) {
      console.error("No world or publicClient");
      return;
    }
    console.log("PICKUP CALLBACK");
    console.log(opts);
    try {

      const txRequest = await publicClient.simulateContract({
        ...network.worldContract,
        functionName: "borp2__pickup",
        args: [
          opts.deliveryId,
        ] as any,
        account: walletClient.account.address
      });
      
      handleSendTx(txRequest.request, () => {
        console.log("Item Delivered");
        handleOpenToast(
          Severity.Success,
          undefined,
          "Delivery Order Fulfilled"
        );
      });
    } catch(e) {
      handleOpenToast(
        Severity.Error,
        undefined,
        "Transaction failed to execute"
      );
      console.error(e);
    }

  }

  var pickupTable = (
    <div>
      Rebuffering...
    </div>
  );

  var deliveryTable = (
    <div>
      Rebuffering...
    </div>
  );

  var supplyRequestTable = (
    <div>
      Rebuffering...
    </div>
  );

  if (itemLikes.length > 0) {

    var hasPickupOrders = false;
    pickupTable = (
    <div className="Quantum-Container">
      <h1>Supply Request Pickup</h1>
      <table className="items-center delivery-table">
        <thead>
          <tr>
            <th>Pickup</th>
          </tr>
        </thead>
        <tbody>
          {deliveries.filter((delivery) => {
            const walletAddr = walletClient?.account?.address;
            const isMyOrder = walletAddr && delivery.value.receiver.toLowerCase() === walletAddr.toLowerCase();
            // only show orders we can fullfill
            return delivery.value.delivered && isMyOrder;
          }).map((delivery) => {
            hasPickupOrders = true;
            const ssu = deployables[delivery.value.smartObjectId.toString()];
            const ssuName = ssu?.name || delivery.value.smartObjectId.toString();

            const senderChar = characters[delivery.value.sender.toString().toLowerCase()];
            const receiverChar = characters[delivery.value.receiver.toString().toLowerCase()];
            var senderName = senderChar?.name || delivery.value.sender.toString();
            if (delivery.value.sender.startsWith("0x00000000000")) {
              senderName = "";
            }
            const receiverName = receiverChar?.name || delivery.value.receiver.toString();

            const walletAddr = walletClient?.account?.address;
            const isMyOrder = walletAddr && delivery.value.receiver.toLowerCase() === walletAddr.toLowerCase();
            const itemId = delivery.value.itemId;
            const hexString = itemId.toString(16).padStart(64, '0');
            const item = items[hexString];
            const likesForItem = itemLikes.find((l) => l.key.itemId.toString() === delivery.value.itemId.toString());
            const itemQuantity = BigInt(delivery.value.itemQuantity);
            const totalLikes = (likesForItem?.value.likes || BigInt(0)) * itemQuantity;

            return (
            <tr key={delivery.key.deliveryId}>
              <td style={{ maxWidth: '6em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                <p>SSU: {ssuName}</p>
                <p>Item: {item?.name || "000"} | QTY: {delivery.value.itemQuantity.toString()} | Likes: {totalLikes.toString()}</p>
                <p>Status: {delivery.value.delivered ? "Delivered" : "Pending"} | Receiver: '{receiverName}' | Sender: {senderName}</p>
                {!delivery.value.delivered && <button className="primary primary-sm" onClick={() => deliverCallback({ deliveryId: delivery.key.deliveryId })}>Deliver</button>}
                {(delivery.value.delivered && isMyOrder) && <button className="primary primary-sm" onClick={() => pickupCallback({ deliveryId: delivery.key.deliveryId })}>Pick up</button>}
              </td>
            </tr>
          )})}
        </tbody>
      </table>
    </div>
    );

    if (!hasPickupOrders) {
      pickupTable = (
        <div className="Quantum-Container">
          <h1>Supply Request Pickup</h1>
          <p>No pending supply requests to pick up</p>
        </div>
      )
    }

    deliveryTable = (
      <div className="Quantum-Container">
      <h1>Unfulfilled Supply Requests</h1>
      <table className="items-center delivery-table">
        <thead>
          <tr>
            <th>Delivery</th>
          </tr>
        </thead>
        <tbody>
          {deliveries.filter((delivery) => {
            const walletAddr = walletClient?.account?.address;
            const isMyOrder = walletAddr && delivery.value.receiver.toLowerCase() === walletAddr.toLowerCase();
            // only show orders we can fullfill
            return !delivery.value.delivered && !isMyOrder;
          }).map((delivery) => {
            const ssu = deployables[delivery.value.smartObjectId.toString()];
            const ssuName = ssu?.name || delivery.value.smartObjectId.toString();

            const senderChar = characters[delivery.value.sender.toString().toLowerCase()];
            const receiverChar = characters[delivery.value.receiver.toString().toLowerCase()];
            var senderName = senderChar?.name || delivery.value.sender.toString();
            if (delivery.value.sender.startsWith("0x00000000000")) {
              senderName = "";
            }
            const receiverName = receiverChar?.name || delivery.value.receiver.toString();

            const walletAddr = walletClient?.account?.address;
            const isMyOrder = walletAddr && delivery.value.receiver.toLowerCase() === walletAddr.toLowerCase();
            const itemId = delivery.value.itemId;
            const hexString = itemId.toString(16).padStart(64, '0');
            const item = items[hexString];
            const likesForItem = itemLikes.find((l) => l.key.itemId.toString() === delivery.value.itemId.toString());
            const itemQuantity = BigInt(delivery.value.itemQuantity);
            const totalLikes = (likesForItem?.value.likes || BigInt(0)) * itemQuantity;

            return (
            <tr key={delivery.key.deliveryId}>
              <td style={{ maxWidth: '6em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                <p>SSU: {ssuName}</p>
                <p>Item: {item?.name || "000"} | QTY: {delivery.value.itemQuantity.toString()} | Likes: {totalLikes.toString()}</p>
                <p>Status: {delivery.value.delivered ? "Delivered" : "Pending"} | Receiver: '{receiverName}' | Sender: {senderName}</p>
                {!delivery.value.delivered && <button className="primary primary-sm" onClick={() => deliverCallback({ deliveryId: delivery.key.deliveryId })}>Deliver</button>}
                {(delivery.value.delivered && isMyOrder) && <button className="primary primary-sm" onClick={() => pickupCallback({ deliveryId: delivery.key.deliveryId })}>Pick up</button>}
              </td>
            </tr>
          )})}
        </tbody>
      </table>
    </div>
    )


    var hasSupplyRequestOrders = false;
    supplyRequestTable = (
    <div className="Quantum-Container">
      <h1>Your Pending Supply Request Orders</h1>
      <table className="items-center delivery-table">
        <thead>
          <tr>
            <th>Supply Request</th>
          </tr>
        </thead>
        <tbody>
          {deliveries.filter((delivery) => {
            const walletAddr = walletClient?.account?.address;
            const isMyOrder = walletAddr && delivery.value.receiver.toLowerCase() === walletAddr.toLowerCase();
            // only show our pending orders
            return !delivery.value.delivered && isMyOrder;
          }).map((delivery) => {
            hasSupplyRequestOrders = true;
            const ssu = deployables[delivery.value.smartObjectId.toString()];
            const ssuName = ssu?.name || delivery.value.smartObjectId.toString();

            const senderChar = characters[delivery.value.sender.toString().toLowerCase()];
            const receiverChar = characters[delivery.value.receiver.toString().toLowerCase()];
            var senderName = senderChar?.name || delivery.value.sender.toString();
            if (delivery.value.sender.startsWith("0x00000000000")) {
              senderName = "";
            }
            const receiverName = receiverChar?.name || delivery.value.receiver.toString();

            const walletAddr = walletClient?.account?.address;
            const isMyOrder = walletAddr && delivery.value.receiver.toLowerCase() === walletAddr.toLowerCase();
            const itemId = delivery.value.itemId;
            const hexString = itemId.toString(16).padStart(64, '0');
            const item = items[hexString];
            const likesForItem = itemLikes.find((l) => l.key.itemId.toString() === delivery.value.itemId.toString());
            const itemQuantity = BigInt(delivery.value.itemQuantity);
            const totalLikes = (likesForItem?.value.likes || BigInt(0)) * itemQuantity;

            // TODO remove deliver button
            return (
            <tr key={delivery.key.deliveryId}>
              <td style={{ maxWidth: '6em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                <p>SSU: {ssuName}</p>
                <p>Item: {item?.name || "000"} | QTY: {delivery.value.itemQuantity.toString()} | Likes: {totalLikes.toString()}</p>
                <p>Status: {delivery.value.delivered ? "Delivered" : "Pending"} | Receiver: '{receiverName}' | Sender: {senderName}</p>
                {!delivery.value.delivered && <button className="primary primary-sm" onClick={() => deliverCallback({ deliveryId: delivery.key.deliveryId })}>Deliver</button>}
                {(delivery.value.delivered && isMyOrder) && <button className="primary primary-sm" onClick={() => pickupCallback({ deliveryId: delivery.key.deliveryId })}>Pick up</button>}
              </td>
            </tr>
          )})}
        </tbody>
      </table>
    </div>
    );

    if (!hasSupplyRequestOrders) {
      supplyRequestTable = (
        <div className="Quantum-Container">
          <h1>Your Pending Supply Request Orders</h1>
          <p>No pending supply requests</p>
        </div>
      )
    }

  }

  return (
    <div>
    <div className="Quantum-Container">
      <ul>

      <li>Likes: {(thisPlayerMetrics ? thisPlayerMetrics.value.likes : BigInt(0)).toString()}</li>
      <li>Deliveries made: {(thisPlayerMetrics ? thisPlayerMetrics.value.deliveriesCompleted : BigInt(0)).toString()}</li>
      <li>Pending Supply Requests: {(thisPlayerMetrics ? thisPlayerMetrics.value.pendingSupplyCount : BigInt(0)).toString()} / 5</li>
      </ul>
    </div>
    <div className="Quantum-Container font-normal text-xs !py-4">
      <p>Fulfilling Pending Supply Requests will earn you Likes!</p>
      <p>You may request items with the requisition form on this page.</p>
      <p>You may deliver supplies to other players by placing them in the SSU inventory, and selecting "Deliver" for the order.</p>
      <p>If your requested order is supplied by another player, you may pick them up with the "Pickup" button</p>
    </div>
    {smartObjectId &&
    <div className="Quantum-Container">
      <CreateDelivery submitDisabled={submitDisabled} typeMap={types} smartObjectId={smartObjectId} network={network} createDeliveryCallback={createCallback}/>
    </div>
    }
    {supplyRequestTable}
    {pickupTable}
    {deliveryTable}
    </div>
  );
}