
import { BaseMetadataSchema } from '../../types.js';

// Contract address and chain configuration for the Optimism7683 solver
const metadata = {
  protocolName: 'Optimism7683',
  intentSources: [
    // {
    //   address: '0x33B2f5f82dD8143d0752A110b70b46AD0ECda1a3',
    //   chainName: 'optimismsepolia',
    // },
    // {
    //   address: '0x33B2f5f82dD8143d0752A110b70b46AD0ECda1a3', // Use the appropriate contract address for opchaina
    //   chainName: 'devnet0',
    //   // You can add these optional parameters if needed
    //   initialBlock: 0,           // Start listening from block 0
    //   pollInterval: 1000,        // Poll every 1 second
    //   confirmationBlocks: 1      // Wait for 1 confirmation
    // },
    // {
    //   address: '0x33B2f5f82dD8143d0752A110b70b46AD0ECda1a3', // Use the appropriate contract address for opchaina
    //   chainName: 'devnet1',
    //   // You can add these optional parameters if needed
    //   initialBlock: 0,           // Start listening from block 0
    //   pollInterval: 1000,        // Poll every 1 second
    //   confirmationBlocks: 1      // Wait for 1 confirmation
    // },
    {
      address: '0xc5fB2E890f4e2ca9bDe6ab867410E4D5bd6749BA', // Use the appropriate contract address for opchaina
      chainName: 'opchaina',
      // You can add these optional parameters if needed
      initialBlock: 0,           // Start listening from block 0
      pollInterval: 1000,        // Poll every 1 second
      confirmationBlocks: 1      // Wait for 1 confirmation
    },
    {
      address: '0xc5fB2E890f4e2ca9bDe6ab867410E4D5bd6749BA', // Use the appropriate contract address for opchaina
      chainName: 'opchainb',
      // You can add these optional parameters if needed
      initialBlock: 0,           // Start listening from block 0
      pollInterval: 1000,        // Poll every 1 second
      confirmationBlocks: 1      // Wait for 1 confirmation
    }
  ]
};

BaseMetadataSchema.parse(metadata);
export default metadata;
