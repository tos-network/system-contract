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

Install poetry:
```shell script
curl -sSL https://install.python-poetry.org | python3 -
poetry install
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


## How to update contract interface for test

```shell script
// get metadata
forge build

// generate interface
cast interface ${workspace}/out/{contract_name}.sol/${contract_name}.json -p ^0.8.0 -n ${contract_name} > ${workspace}/test/utils/interface/I${contract_name}.sol
```

## License

The library is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0),
also included in our repository in the [LICENSE](LICENSE) file.
