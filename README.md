# Master/Child game design implementation

## Phase 1 - setting-up contracts

- A) Choose your _default token_ (address, name) -> input parameters for next step
- B) Deploy master (contracts/master-example/MasterParent.sol) - _defaultToken (address), tokenName_
- C) Deploy game (contracts/master-example/Roulette.sol) -> save address for E
- D) Deploy game (contracts/master-example/Slots.sol) -> save address for E
- E) Add games to master by using `masterContract.addGame(_newGameAddress, _newGameName, _maximumBet (Wei))`

## Phase 2 - allocating funds for each game

- Before allocating funds(tokens) for each game make sure you've added any other additional tokens to the master contract:
  using: `masterContract.addToken()` with 2 parameters: \_tokenAddress, \_tokenName

- Now that you've added tokens you can allocate any of those for each game by using the `masterContract.addFunds()` function with the following parameters: \_gameID, \_tokenAmount, \_tokenName (\_gameID is the index of the game in array (0, 1, 2, etc...))

  _Important: Before executing this function make sure this contract is approved to access your wallet funds_

- You can also allocate funds manually. Simply send tokens to the masterContract address and use the `masterContract.manaulAllocation()` function

- To withdraw funds from the contract use the `masterContract.withdrawCollateral()` function with the \_gameID, \_amount, and \_tokensName parameters. For example: `masterContract.withdrawCollateral(0, 100000000000000, "MANA")`

  _(or simply call withdrawMaxTokenBalance() using the \_tokenName to withdraw all of the contract funds)_

## Phase 3 - play games

```javascript
    masterContract.play(_gameID, _userAddress, _landID, _machineID, _betIDs[], _betValues[], _betAmount[], _localhash, _tokenName);
    masterContract.play(0, address, uint256, uint256, uint256[], uint256[], uint256[], bytes32, string); // playing roulette
    masterContract.play(0, 0x641ad78baca220c5bd28b51ce8e0f495e85fe689, 1, 1, [3302], [0], [1000000000000000], localhash, "MANA"); // betting on Even
    masterContract.play(0, 0x641ad78baca220c5bd28b51ce8e0f495e85fe689, 1, 1, [3302, 3306], [0,0], [1000000000000000, 1000000000000000], [1,1], _localhash, "MANA"); // betting on Even and High (>=19)

    masterContract.play(1, 0x641ad78baca220c5bd28b51ce8e0f495e85fe689, 1, 1, [1101], [0], [1000000000000000000], _localhash, "MANA") // playing slots
```

## For testing:

npm install -g truffle@latest
npm install -g ethereumjs-testrpc@latest
npm install -g ganache-cli@latest

start ganachi

npm run test-master
