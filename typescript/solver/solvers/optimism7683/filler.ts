import type { MultiProvider } from "@hyperlane-xyz/sdk";
import { BaseFiller } from '../BaseFiller.js';
import { metadata, allowBlockLists } from './config/index.js';
import type { Optimism7683Metadata, IntentData, ParsedArgs, OpenEventArgs } from './types.js';
import { log } from '../../logger.js';
import { addressToBytes32, bytes32ToAddress, Result } from "@hyperlane-xyz/utils";
import { Erc20__factory } from "../../typechain/factories/contracts/Erc20__factory.js";
import { Optimism7683__factory } from "../../typechain/factories/solvers/optimism7683/contracts/Optimism7683__factory.js";
import { AddressZero, MaxUint256 } from "@ethersproject/constants";
// import { parse } from "dotenv-flow";

export class Optimism7683Filler extends BaseFiller<Optimism7683Metadata, ParsedArgs, IntentData> {
  constructor(multiProvider: MultiProvider) {
    super(multiProvider, allowBlockLists, metadata, log);
  }

  protected async retrieveOriginInfo(
    parsedArgs: ParsedArgs,
    chainName: string
  ): Promise<Array<string>> {
    return [`Origin chain: ${chainName}, Sender: ${parsedArgs.senderAddress}`];
  }

  protected async retrieveTargetInfo(
    parsedArgs: ParsedArgs
  ): Promise<Array<string>> {
    return parsedArgs.recipients.map(
      ({ destinationChainName, recipientAddress }) =>
        `Destination chain: ${destinationChainName}, Recipient: ${recipientAddress}`
    );
  }

  protected async fill(
    parsedArgs: ParsedArgs,
    data: IntentData,
    originChainName: string,
    blockNumber: number
  ): Promise<void> {
    this.log.info({
      msg: "Filling Intent",
      intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
      data: data,
      parsedArgs: parsedArgs,
      originChainName: originChainName,
      blockNumber: blockNumber
    });

    await Promise.all(
      data.maxSpent.map(
        async ({ amount, chainId, recipient, token: tokenAddress }) => {
          try {
            tokenAddress = bytes32ToAddress(tokenAddress);
            recipient = bytes32ToAddress(recipient);
            const _chainId = chainId.toString();

            this.log.debug({
              msg: "Preparing approval",
              tokenAddress,
              recipient,
              _chainId
            });

            const filler = this.multiProvider.getSigner(_chainId);

            if (tokenAddress === AddressZero) {
              // native token
              return;
            }

            const token = Erc20__factory.connect(tokenAddress, filler);

            this.log.debug({
              msg: "token",
              tokenAddress: token.address,
            });

            const fillerAddress = await filler.getAddress();

            this.log.debug({
              msg: "Filler address",
              protocolName: this.metadata.protocolName,
              fillerAddress,
              chainId: _chainId,
            });

            const allowance = await token.allowance(fillerAddress, recipient);
            
            this.log.debug({
              msg: "Checking allowance",
              protocolName: this.metadata.protocolName,
              tokenAddress,
              recipient,
              chainId: _chainId,
              allowance: allowance.toString()
            });

            if (allowance.lt(amount)) {
              try {
                const tx = await Erc20__factory.connect(
                  tokenAddress,
                  filler,
                ).approve(recipient, MaxUint256);

                const receipt = await tx.wait();
                const baseUrl =
                  this.multiProvider.getChainMetadata(_chainId).blockExplorers?.[0]
                    .url;

                this.log.debug({
                  msg: "Approval",
                  protocolName: this.metadata.protocolName,
                  amount: MaxUint256.toString(),
                  tokenAddress,
                  recipient,
                  chainId: _chainId,
                  tx: baseUrl
                    ? `${baseUrl}/tx/${receipt.transactionHash}`
                    : `${receipt.transactionHash}`,
                });
              } catch (approvalError: any) {
                this.log.error({
                  msg: "Approval failed",
                  protocolName: this.metadata.protocolName,
                  tokenAddress,
                  recipient,
                  chainId: _chainId,
                  error: approvalError.message || approvalError,
                  stack: approvalError.stack,
                });
                throw new Error(`Token approval failed: ${approvalError.message}`);
              }
            } else {
              this.log.debug({
                msg: "Approval not required",
                protocolName: this.metadata.protocolName,
                amount: amount.toString(),
                allowance: allowance.toString(),
                tokenAddress,
                recipient,
                chainId: _chainId,
              });
            }
          } catch (error: any) {
            this.log.error({
              msg: "Error during approval process",
              protocolName: this.metadata.protocolName,
              error: error.message || error,
              stack: error.stack,
            });
            throw error;
          }
        },
      ),
    ).catch(error => {
      this.log.error({
        msg: "Failed to process approvals",
        intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
        error: error.message || error,
        stack: error.stack,
      });
      throw error;
    });

    this.log.debug({
      msg: "Filling instructions",
      intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
      fillInstructions: data.fillInstructions,
    });

    await Promise.all(
      data.fillInstructions.map(
        async (
          { destinationChainId, destinationSettler, originData },
          index,
        ) => {
          try {
            destinationSettler = bytes32ToAddress(destinationSettler);
            const _chainId = destinationChainId.toString();

            this.log.debug({
              msg: "Processing fill instruction",
              chainId: _chainId,
              destinationSettler,
              instructionIndex: index,
            });

            const filler = this.multiProvider.getSigner(_chainId);
            const fillerAddress = await filler.getAddress();
            const destination = Optimism7683__factory.connect(
              destinationSettler,
              filler,
            );

            const value =
              bytes32ToAddress(data.maxSpent[index].token) === AddressZero
                ? data.maxSpent[index].amount
                : undefined;

            this.log.debug({
              msg: "Executing fill transaction",
              chainId: _chainId,
              destinationSettler,
              value: value ? value.toString() : "0",
              fillerAddress,
            });

            // Depending on the implementation we may call `destination.fill` directly or call some other
            // contract that will produce the funds needed to execute this leg and then in turn call
            // `destination.fill`
            try {
              const tx = await destination.fill(
                parsedArgs.orderId,
                originData,
                addressToBytes32(fillerAddress),
                { value },
              );

              const receipt = await tx.wait();
              const baseUrl =
                this.multiProvider.getChainMetadata(_chainId).blockExplorers?.[0]
                  .url;

              const txInfo = baseUrl
                ? `${baseUrl}/tx/${receipt.transactionHash}`
                : receipt.transactionHash;

              log.info({
                msg: "Filled Intent",
                intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
                txDetails: txInfo,
                txHash: receipt.transactionHash,
              });
            } catch (fillError: any) {
              this.log.error({
                msg: "Fill transaction failed",
                intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
                chainId: _chainId,
                destinationSettler,
                error: fillError.message || fillError,
                stack: fillError.stack,
              });
              throw new Error(`Fill transaction failed: ${fillError.message}`);
            }
          } catch (error: any) {
            this.log.error({
              msg: "Error processing fill instruction",
              intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
              instructionIndex: index,
              error: error.message || error,
              stack: error.stack,
            });
            throw error;
          }
        },
      ),
    ).catch(error => {
      this.log.error({
        msg: "Failed to process fill instructions",
        intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
        error: error.message || error,
        stack: error.stack,
      });
      throw error;
    });
  }

  protected async prepareIntent(
    parsedArgs: OpenEventArgs,
  ): Promise<Result<IntentData>> {
    log.info({
      msg: "Preparing Intent",
      parsedArgs: parsedArgs,
    });
    const { fillInstructions, maxSpent } = parsedArgs.resolvedOrder;

    try {
      await super.prepareIntent(parsedArgs);

      return { data: { fillInstructions, maxSpent }, success: true };
    } catch (error: any) {
      return {
        error: error.message ?? "Failed to prepare Optimism7683 Intent.",
        success: false,
      };
    }
  }

  protected async settleOrder(
    parsedArgs: OpenEventArgs,
    data: IntentData,
    originChainName: string
  ): Promise<void> {
    log.info({
      msg: "Settling Intent",
      intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
    });

    const destinationSettlers = data.fillInstructions.reduce<
      Record<string, Array<string>>
    >((acc, fillInstruction) => {
      const destinationChain = fillInstruction.destinationChainId.toString();
      const destinationSettler = bytes32ToAddress(
        fillInstruction.destinationSettler,
      );

      acc[destinationChain] ||= [];
      acc[destinationChain].push(destinationSettler);

      return acc;
    }, {});

    await Promise.all(
      Object.entries(destinationSettlers).map(
        async ([destinationChain, settlers]) => {
          const uniqueSettlers = [...new Set(settlers)];
          const filler = this.multiProvider.getSigner(destinationChain);

          return Promise.all(
            uniqueSettlers.map(async (destinationSettler) => {
              const destination = Optimism7683__factory.connect(
                destinationSettler,
                filler,
              );
              try {
                const tx = await destination.settle([parsedArgs.orderId], {
                  // value,
                  // gasLimit: gasLimit.mul(110).div(100),
                });

                const receipt = await tx.wait();

                log.info({
                  msg: "Settled Intent",
                  intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
                  txHash: receipt.transactionHash,
                });
              } catch (error) {
                log.error({
                  msg: `Failed settling`,
                  intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
                  error,
                });
                return;
              }
            }),
          );
        },
      ),
    );
  }
}

export const create = (multiProvider: MultiProvider) => {
  log.info({
      msg: "Creating Optimism7683 Filler", 
    });
  return new Optimism7683Filler(multiProvider).create();
}
