# AA Wallet implemented from ERC 7337

## Features
- Transfer ETH through Owner Validator
    - `setOwnerValidator()`
- Transfer ETH through Custom Validator
    - `execute()`
    - `executeBatch()`

## How to build
The project is built with [foundry](https://github.com/foundry-rs/foundry). Install it if you haven't.

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Run the following command to clone the repo and build
```bash
git clone git@github.com:andylinee/aws_final_project.git
cd aws_final_project
forge install
forge build
```

## Testing
To run the tests, simply run the following command.
```bash
forge test -vvvvv --ffi
```