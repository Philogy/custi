# Custi the Custodian

Custi is a trustless self-custodial smart wallet with easy to configure recovery options.

The main goal of this small project is to create a simple and secure smart
wallet which allows you to recover your own assets in case of a loss of private
keys via social recovery and for your assets to be easily "inherited" by someone
of your choosing should you pass away.

Furthermore the vault should allow you to protect yourself from "5$ wrench
attacks" in certain scenarios. A "5$ wrench attack" is an attack whereby assets
are extorted from a victim using the threat of physical violence.


## Custi V1
### V1 Progress 🚧

- [x] Basic custody: Owner should be able to deposit / withdraw assets from
  their vault
- [x] Pinging: Vault should keep track of last interaction from owner,
  prerequisite for recovery
- [x] Locking: Owner should be able to lock themselves out of their vault for a
  set period of time
- [ ] Multi-Sig Recovery Agents: Allow easy configuration of recovery options
  that require multiple signatures


### Functional Requirements V1
**Vault `CustiVaultV1`:**
1. Only the owner can directly access custody methods if the vault is not locked (`transfer{...}`, `customCall`)
2. Only the owner can directly lock the vault till a specific block timestamp is
   reached
3. The owner can only ping the vault while it's not locked
4. An account is a guardian if contained in the guardian merkle tree along with
   a delay
5. A guardian may only change the owner of a vault if their associated delay
   after the last ping has elapsed.
6. The owner may only extend the vault's lock while it's still locked
7. The vault can only be initialized once
8. The vault owner cannot become the zero-address once initialized


**Note:** This repo is _unaudited_, no guarantee about the security of the smart contracts contained in this repo are made.

