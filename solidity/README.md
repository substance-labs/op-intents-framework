# ERC7683 Reference Implementation

## Overview

This project is centered around the [Base7683](./src/Base7683.sol) contract, which serves as the foundational component
for implementing the interfaces defined in the
[ERC7683 specification](https://github.com/across-protocol/ERCs/blob/master/ERCS/erc-7683.md).

As reference, the following contracts build upon `Base7683`:

1. [BasicSwap7683](./src/BasicSwap7683.sol) The `BasicSwap7683` contract extends `Base7683` by implementing logic for a
   specific `orderData` type as defined in the [OrderEncoder](./src/libs/OrderEncoder.sol). This implementation
   facilitates token swaps, enabling the exchange of an `inputToken` on the origin chain for an `outputToken` on the
   destination chain.

2. [Optimism7683](./src/Optimism7683.sol) The `Optimism7683` contract extends `BasicSwap7683` by integrating the Optimism
   L2-to-L2 cross-domain messaging protocol. This implementation leverages the native interoperability between OP Stack
   chains (such as Optimism, Base, and other OP Stack-based L2s) to facilitate secure and efficient cross-chain order
   settlement and refunds. The contract uses the `L2ToL2CrossDomainMessenger` predeploy to handle cross-chain messaging
   without requiring external verification infrastructure.

## Optimism7683 Implementation

The Optimism7683 contract provides a streamlined implementation for cross-chain order execution between OP Stack chains. Key features include:

- Uses the native L2-to-L2 cross-domain messaging protocol instead of external bridge systems
- Leverages the standard predeploy address for L2ToL2CrossDomainMessenger
- Implements chain identifier mapping via the `destinationContracts` mapping
- Provides admin functions to set and update destination contracts on connected chains
- Ensures secure and efficient message passing between Optimism ecosystem chains

## Usage

For deploying the router you have to run the `yarn run:deployOptimism7683`. Make sure the following environment
variable are set:

- `DEPLOYER_PK`: deployer private key
- `PERMIT2`: Permit2 address on `NETWORK_NAME`
- `ROUTER_OWNER`: address of the router owner
- `PROXY_ADMIN_OWNER`: address of the ProxyAdmin owner, `ROUTER_OWNER` would be used if this is not set. The router is
  deployed using a `TransparentUpgradeableProxy`, so a ProxyAdmin contract is deployed and set as the admin of the
  proxy.
- `OPTIMISM7683_SALT`: a single use by chain salt for deploying the router. Make sure you use the same on all
  chains so the routers are deployed all under the same address.
- `DOMAINS`: the domains list of the routers to enroll, separated by commas

### Open an Order

For opening an onchain order you can run `yarn run:openOrder`. Make sure the following environment variable are set:

- `ROUTER_OWNER_PK`: the router's owner private key. Only the owner can enroll routers
- `ORDER_SENDER`: address of order sender
- `ORDER_RECIPIENT`: address of order recipient
- `ITT_INPUT`: token input address
- `ITT_OUTPUT`: token output address
- `AMOUNT_IN`: amount in
- `AMOUNT_OUT`: amount out
- `DESTINATION_DOMAIN`: destination domain id

### Refund Order

For refunding an expired order you can run `yarn run:refundOrder`. Make sure the following environment variable are set:

- `NETWORK`: the name of the network you want to run the script, it should be the destination network of your order
- `USER_PK`: the private key to use for executing the tx
- `ORDER_ORIGIN`: the chain id of the order's origin chain
- `ORDER_FILL_DEADLINE`: the `fillDeadline` used when opening the order
- `ORDER_DATA`: the `orderData` used when opening the order

you can find the `fillDeadline` and `orderData` inspecting the open transaction on etherscan

---

## Usage

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ yarn build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ yarn clean
```

### Coverage

Get a test coverage report:

```sh
$ yarn coverage
```

### Format

Format the contracts:

```sh
$ yarn sol:fmt
```

### Gas Usage

### Lint

Lint the contracts:

```sh
$ yarn lint
```

### Test

Run the tests:

```sh
$ yarn test
```

Generate test coverage and output result to the terminal:

```sh
$ yarn test:coverage
```

Generate test coverage with lcov report (you'll have to open the `./coverage/index.html` file in your browser, to do so
simply copy paste the path):

```sh
$ yarn test:coverage:report
```
