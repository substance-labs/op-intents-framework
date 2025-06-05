
import z from 'zod';
import { BaseMetadataSchema, BaseIntentData } from '../types.js';
import type { ParsedArgs as BaseParsedArgs } from '../BaseFiller.js';
import type { OpenEventObject } from "../../typechain/hyperlane7683/contracts/Hyperlane7683.js";
import type { BigNumber } from 'ethers';

export const Optimism7683MetadataSchema = BaseMetadataSchema.extend({
  // Add any additional metadata fields here if needed
});

export type Optimism7683Metadata = z.infer<typeof Optimism7683MetadataSchema>;

export type ExtractStruct<T, K extends object> = T extends (infer U & K)[]
  ? U[]
  : never;

export type ResolvedCrossChainOrder = Omit<
  OpenEventObject["resolvedOrder"],
  "minReceived" | "maxSpent" | "fillInstructions"
> & {
  minReceived: ExtractStruct<
    OpenEventObject["resolvedOrder"]["minReceived"],
    { token: string }
  >;
  maxSpent: ExtractStruct<
    OpenEventObject["resolvedOrder"]["maxSpent"],
    { token: string }
  >;
  fillInstructions: ExtractStruct<
    OpenEventObject["resolvedOrder"]["fillInstructions"],
    { destinationChainId: BigNumber }
  >;
};

export interface OpenEventArgs {
  orderId: string;
  senderAddress: ResolvedCrossChainOrder["user"];
  recipients: Array<{
    destinationChainName: string;
    recipientAddress: string;
  }>;
  resolvedOrder: ResolvedCrossChainOrder;
}

export interface IntentData extends BaseIntentData {
  fillInstructions: ResolvedCrossChainOrder["fillInstructions"];
  maxSpent: ResolvedCrossChainOrder["maxSpent"];
}

export interface ParsedArgs extends BaseParsedArgs {
  orderId: string;
  senderAddress: string;
  recipients: Array<{
    destinationChainName: string;
    recipientAddress: string;
  }>;
  resolvedOrder: ResolvedCrossChainOrder;
  // Add any additional parsed args fields here
}
