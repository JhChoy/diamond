# Foundry Diamond Library (with CreateX)

This repository provides a convenient way to implement the Diamond Proxy pattern ([EIP-2535](https://eips.ethereum.org/EIPS/eip-2535)) in a Foundry (Forge) environment, along with [CreateX](https://github.com/pcaversaccio/createx) integration for multiple deployment methods (create2, create3, etc.).

## Overview
The main goal is to simplify the creation and management of modular, upgradeable smart contracts by leveraging the Diamond Proxy pattern.
This project is inspired by [diamond-3-hardhat](https://github.com/mudgen/diamond-3-hardhat).

You can find the sample boilerplate code at [diamond-boilerplate](https://github.com/JhChoy/diamond-boilerplate). To get started immediately, clone this repository.

## Installation
```bash
forge install JhChoy/diamond
```

## Features
- Diamond Proxy pattern implementation
- CreateX integration for deterministic deployments
- Modular contract architecture
- Upgradeable smart contracts
- Chain-agnostic deployment addresses

## Project Structure
```
diamond/
├── src/
│   ├── diamond/        # Core Diamond implementation
│   ├── interfaces/     # Contract interfaces
│   └── libraries/      # Shared libraries
├── test/              # Test files
└── script/            # Deployment scripts
```

## Testing
```bash
forge test
```

## Why CreateX?
Create3: Since DiamondApp should be deployed only once per project, we use Create3 to ensure a deterministic, chain-agnostic address for deployment.
Create2: Facets are implementation contracts that need to be deployed once per chain. During upgrades, if the contract code changes, new deployments are required, which is why we utilize Create2.

## Contribution
All contributions are welcome. If you find any issues, please report them in the Issues section.

## License
MIT
