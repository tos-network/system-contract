# system contracts

This repo hold all the system contracts on TOS Network.

## Prepare

Install node.js dependency:
```shell script
npm install
```

Install foundry:
```shell script
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge install --no-git --no-commit foundry-rs/forge-std@v1.7.3
```

## Build all system contracts
```shell script
forge build

```

## Unit test

Add follow line to .env file in project dir, replace `archive_node` with a valid tos mainnet node url which should be in archive mode:

```text
RPC_TOS=${archive_node}
```

Run forge test:
```shell script
forge test
```

## Flatten all system contracts

```shell script
bash scripts/flatten.sh
```

All system contracts will be flattened and output into `${workspace}/contracts/flattened/`.

## Generate all system contracts abi

```shell script
bash scripts/genabi.sh
```

All system contracts abi will be generated and output into `${workspace}/abi/`.

## License

The library is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0),
also included in our repository in the [LICENSE](./LICENSE) file.
