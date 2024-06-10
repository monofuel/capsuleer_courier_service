import { useState, useEffect } from 'react';
import { keccak256 } from 'js-sha3';
import { AbiItemType } from 'abitype';

// https://blockchain-gateway.nursery.reitnorf.com/types

// types returns an object of key:value pairs

export interface TypeAttribute {
  trait_type: string;
  value: number | string;
}

export interface TypeValue {
  name: string;
  description: string;
  image: string; // Image url is empty when pulling the typeMap, you have to pull individual types
  attributes: TypeAttribute[];
}

export type TypeMap = {
  [key: string]: TypeValue;
}

export function useTypes() {
  // NB. items is a map of hex hashes to TypeValue, not bigInts
  const [types, setTypes] = useState<TypeMap>({});
  const [items, setItems] = useState<TypeMap>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  useEffect(() => {
    const fetchTypes = async () => {
      setLoading(true);
      try {
        const response = await fetch('https://blockchain-gateway-test.nursery.reitnorf.com/types');
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        setTypes(data);
        (window as any).typeMap = data;

        // string memory packed = string(abi.encodePacked("item:devnet-", Strings.toString(typeId)));
        // uint256 itemId = uint256(keccak256(abi.encodePacked(packed)));

        var itemMap: TypeMap = {};
        (window as any).itemMap = itemMap;

        // doh, these are hex! oops
        for (const key of Object.keys(data)) {
          const packed = `item:devnet-${key}`;
          const itemId = keccak256(packed);
          itemMap[itemId] = data[key];
        } 
        setItems(itemMap);


      } catch (error) {
        setError(error);
      } finally {
        setLoading(false);
      }
    };

    fetchTypes();
  }, []);

  return { types, items, loading, error };
}

// - fetch characters with https://blockchain-gateway-test.nursery.reitnorf.com/smartcharacters/
// - fetch smart deployables with https://blockchain-gateway-test.nursery.reitnorf.com/smartdeployables/

export interface CharacterValue {
  address: string;
  name: string;
  image: string; // Image url is empty when pulling the typeMap, you have to pull individual types
  // id: BigInt;
}

export type CharacterMap = {
  [key: string]: CharacterValue;
}

export function useCharacters() {
  const [characters, setCharacters] = useState<CharacterMap>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  if (error) {
    return { characters, loading, error };
  }

  useEffect(() => {
    const fetchCharacters = async () => {
      setLoading(true);
      try {
        const response = await fetch('https://blockchain-gateway-test.nursery.reitnorf.com/smartcharacters');
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();

        const charMap: CharacterMap = {};
        for (const item of data) {
          charMap[item.address.toLowerCase()] = item;
        }

        setCharacters(charMap);
        (window as any).characterMap = charMap;
      } catch (error) {
        setError(error);
      } finally {
        setLoading(false);
      }
    };

    fetchCharacters();
  
  }, []);

  return { characters, loading, error };
}

export interface DeployableValue {
  id: string;
  chainId: number;
  stateId: number;
  state: string;
  isOnline: boolean;
  name: string;
  ownerId: string;
  ownerName: string;
  typeId: number;
}

export type DeployableMap = {
  [key: string]: DeployableValue;
}

export function useDeployables() {
  const [deployables, setDeployables] = useState<DeployableMap>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  if (error) {
    return { deployables, loading, error };
  }

  useEffect(() => {
    const fetchDeployables = async () => {
      setLoading(true);
      try {
        const response = await fetch('https://blockchain-gateway-test.nursery.reitnorf.com/smartdeployables');
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();

        let dMap: DeployableMap = {}
        for (const item of data) {
          dMap[item.id] = item;
        }

        setDeployables(dMap);
        (window as any).deployableMap = dMap;
      } catch (error) {
        setError(error);
      } finally {
        setLoading(false);
      }
    };

    fetchDeployables();
  }, []);

  return { deployables, loading, error };
}