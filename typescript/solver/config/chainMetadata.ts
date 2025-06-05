import { z } from "zod";

import { chainMetadata as defaultChainMetadata } from "@hyperlane-xyz/registry";

import type { ChainMap, ChainMetadata } from "@hyperlane-xyz/sdk";
import { ChainMetadataSchema } from "@hyperlane-xyz/sdk";

import { objMerge } from "@hyperlane-xyz/utils";

const customChainMetadata = {
  devnet0: {
    id: 420120000,
    chainId: 420120000,
    domainId: 420120000,
    name: "devnet0",
    protocol: "ethereum",
    displayName: "OP Devnet 0",
    nativeToken: {
      name: "Ether",
      symbol: "ETH",
      decimals: 18,
    },
    rpcUrls: [
      {
        http: "https://interop-alpha-0.optimism.io",
        pagination: {
          maxBlockRange: 3000,
        },
      },
    ],
    blocks: {
      confirmations: 1,
      estimateBlockTime: 2,
    },
  },
  devnet1: {
    id: 420120000,
    chainId: 420120001,
    domainId: 420120001,
    name: "devnet1",
    protocol: "ethereum",
    displayName: "OP Devnet 1",
    nativeToken: {
      name: "Ether",
      symbol: "ETH",
      decimals: 18,
    },
    rpcUrls: [
      {
        http: "https://interop-alpha-1.optimism.io",
        pagination: {
          maxBlockRange: 3000,
        },
      },
    ],
    blocks: {
      confirmations: 1,
      estimateBlockTime: 2,
    },
  },
  opchaina: {
    id: 901,
    chainId: 901,
    domainId: 901,
    name: "opchaina",
    protocol: "ethereum",
    displayName: "OPChainA",
    nativeToken: {
      name: "Ether",
      symbol: "ETH",
      decimals: 18,
    },
    rpcUrls: [
      {
        http: " http://127.0.0.1:9545",
        pagination: {
          maxBlockRange: 3000,
        },
      },
    ],
    blockExplorers: [
      {
        name: "Blockscout Explorer",
        url: "https://optimism-interop-alpha-1.blockscout.com",
        apiUrl: "https://optimism-interop-alpha-1.blockscout.com/api",
      },
    ],
    blocks: {
      confirmations: 1,
      estimateBlockTime: 2,
    },
  },
  opchainb: {
    id: 902,
    chainId: 902,
    domainId: 902,
    name: "opchainb",
    protocol: "ethereum",
    displayName: "OPChainB",
    nativeToken: {
      name: "Ether",
      symbol: "ETH",
      decimals: 18,
    },
    rpcUrls: [
      {
        http: " http://127.0.0.1:9546",
        pagination: {
          maxBlockRange: 3000,
        },
      },
    ],
    blockExplorers: [
      {
        name: "Blockscout Explorer",
        url: "https://optimism-interop-alpha-1.blockscout.com",
        apiUrl: "https://optimism-interop-alpha-1.blockscout.com/api",
      },
    ],
    blocks: {
      confirmations: 1,
      estimateBlockTime: 2,
    },
  },
};

const chainMetadata = objMerge<ChainMap<ChainMetadata>>(
  defaultChainMetadata,
  customChainMetadata,
  10,
  true,
);

z.record(z.string(), ChainMetadataSchema).parse(chainMetadata);

export { chainMetadata };
