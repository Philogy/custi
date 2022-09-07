# Custi the Custodian

Custi is a trustless self-custodial smart wallet with easy to configure recovery options.

The main goal of this small project is to create a simple and secure smart
wallet which allows you to recover your own assets in case of a loss of private
keys via social recovery and for your assets to be easily "inherited" by someone
of your choosing should you pass away.

Furthermore the vault should allow you to protect yourself from "5$ wrench
attacks" in certain scenarios. A "5$ wrench attack" is an attack whereby assets
are extorted from a victim threat of physical violence.


## Progress V1 🚧

- [ ] Basic custody: Owner should be able to deposit / withdraw assets from
  their vault
- [ ] Pinging: Vault should keep track of last interaction from owner,
  prerequisite for recovery
- [ ] Locking: Owner should be able to lock themselves out of their vault for a
  set period of time
- [ ] Multi-Sig Recovery Agents: Allow easy configuration of recovery options
  that require multiple signatures


**Note:** This repo is _unaudited_, no guarantee about the security of the smart contracts contained in this repo are made.

