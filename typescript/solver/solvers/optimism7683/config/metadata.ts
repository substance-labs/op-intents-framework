import { BaseMetadataSchema } from '../../types.js';
import dotenv from 'dotenv';

dotenv.config();

const CONTRACT_ADDRESSES = process.env.OPTIMISM7683_CONTRACT_ADDRESS?.split(',') || [];
if (CONTRACT_ADDRESSES.length < 2) {
  throw new Error('OPTIMISM7683_CONTRACT_ADDRESS must contain at least two comma-separated addresses');
}

const metadata = {
  protocolName: 'Optimism7683',
  intentSources: [
    {
      address: CONTRACT_ADDRESSES[0],
      chainName: 'opchaina',
      initialBlock: 0,
      pollInterval: 1000,
      confirmationBlocks: 1
    },
    {
      address: CONTRACT_ADDRESSES[1],
      chainName: 'opchainb',
      initialBlock: 0,
      pollInterval: 1000,
      confirmationBlocks: 1
    }
  ]
};

BaseMetadataSchema.parse(metadata);
export default metadata;
