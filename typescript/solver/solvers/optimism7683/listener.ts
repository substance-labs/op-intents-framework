
import { BaseListener } from '../BaseListener.js';
import { metadata } from './config/index.js';
import type { ParsedArgs } from './types.js';
import { log } from '../../logger.js';

import type { TypedEvent, TypedListener } from "../../typechain/common.js";
import { Optimism7683__factory } from "../../typechain/factories/solvers/optimism7683/contracts/Optimism7683__factory.js";
import { ResolvedCrossChainOrderStructOutput } from '../../typechain/solvers/optimism7683/contracts/Optimism7683.js';
import { chainIdsToName } from '../../config/index.js';

type OpenEvent = TypedEvent<[string, ResolvedCrossChainOrderStructOutput]>;

export class Optimism7683Listener extends BaseListener<any, any, ParsedArgs> {
  constructor() {
    super(
      Optimism7683__factory,
      'Open',
      { contracts: [...metadata.intentSources], protocolName: metadata.protocolName },
      log
    );
  }

  protected parseEventArgs(args: Parameters<TypedListener<OpenEvent>>): ParsedArgs {
    // Transform event args into ParsedArgs format
    const [orderId, resolvedOrder] = args;
    return {
      orderId,
      senderAddress: resolvedOrder.user,
      recipients: resolvedOrder.maxSpent.map(({ chainId, recipient }) => ({
        destinationChainName: chainIdsToName[chainId.toString()],
        recipientAddress: recipient,
      })),
      resolvedOrder,
    };
  }
}

export const create = () => new Optimism7683Listener().create();
