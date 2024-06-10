import { useContext, useState, useEffect } from "react";

import { SmartObjectContext, FeedbackContext } from "@eveworld/contexts";
import {
  SmartDeployableInfo,
  NotFound,
  NetworkMismatch,
  EveLoadingAnimation,
  ClickToCopy,
} from "@eveworld/ui-components";
import { abbreviateAddress } from "@eveworld/utils";
import { Severity } from "@eveworld/types";

import SmartStorageUnitActions from "./SmartStorageUnitActions";
import Deliveries from "./Deliveries";
import EquippedModules from "./Modules";
import BaseImage from "../assets/base-image.png";
import Quote from "./Quote";

import { setupNetwork, SetupNetworkResult } from "../mud/setupNetwork";


const songEmbed = (
  <iframe     style={{borderRadius: '12px'}}
    src="https://open.spotify.com/embed/track/6fCpZU76MwKF2TMsgwwhQj?utm_source=generator&theme=0"
    width="100%" height="152"  allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"
    loading="lazy"></iframe>
)

export default function EntityView() {
  const { smartDeployable, loading, isCurrentChain } =
    useContext(SmartObjectContext);
  const { handleOpenToast, handleClose } = useContext(FeedbackContext);

  useEffect(() => {
    if (loading) {
      handleOpenToast(Severity.Info, undefined, "Loading...");
    } else {
      handleClose();
    }
  }, [loading]);

  const [network, setNetwork] = useState<SetupNetworkResult | null>(null);

  useEffect(() => {
    const fetchNetwork = async () => {
      const net = await setupNetwork();
      setNetwork(net);
      (window as any).networkResult = net;
    };

    fetchNetwork();
  }, []);

  if (!loading && !smartDeployable) {
    return <NotFound />;
  }

  if (!network) {
    return (
      <div>
        Loading...
      </div>
    );
  }

  return (
    <EveLoadingAnimation position="diagonal">
      <div className="grid border border-brightquantum bg-crude">
        <div className="flex flex-col align-center border border-brightquantum">
          <div className="bg-brightquantum text-crude flex items-stretch justify-between px-2 py-1 font-semibold">
            <span className="uppercase">{smartDeployable?.name}</span>
            <span className="flex flex-row items-center">
              {abbreviateAddress(smartDeployable?.id)}
              <ClickToCopy
                text={smartDeployable?.id}
                className="text-crude"
              />{" "}
            </span>
          </div>
          <Quote/>
          <Deliveries network={network}/>
        </div>

        <div className="grid grid-cols-2 mobile:grid-cols-1 bg-crude">
          <EquippedModules />
        </div>
      </div>
    </EveLoadingAnimation>
  );
}
