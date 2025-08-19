# CyberBounty

A decentralized cybersecurity bounty hunting platform that enables transparent, trustless bug bounty programs. Companies post bounties on-chain with escrowed rewards, ethical hackers submit findings securely, and a community of validators (via DAO) assesses submissions to ensure fair payouts — solving issues like opacity, disputes, and centralization in traditional platforms like HackerOne.

---

## Overview

CyberBounty consists of four main smart contracts that together create a secure, immutable ecosystem for cybersecurity bounty hunting:

1. **BountyFactory Contract** – Creates and manages bounty programs with escrowed funds.
2. **SubmissionHandler Contract** – Handles secure submission of bug reports and claims.
3. **ValidationDAO Contract** – Enables community voting on submission validity.
4. **PayoutEscrow Contract** – Automates reward distribution based on validation outcomes.

---

## Features

- **On-chain bounty creation** with customizable reward tiers and scopes  
- **Encrypted submissions** to protect sensitive vulnerability details  
- **DAO governance** for impartial validation and dispute resolution  
- **Automated escrows** for trustless payouts to hunters  
- **Immutable audit trails** for all submissions, votes, and transactions  
- **Token staking** for validators to incentivize honest participation  
- **Integration hooks** for off-chain proof-of-concept verification  

---

## Smart Contracts

### BountyFactory Contract
- Create new bounty programs with defined scopes (e.g., smart contracts, web apps)
- Escrow funds in stablecoins or native tokens for rewards
- Set reward tiers based on vulnerability severity (e.g., low, medium, high, critical)

### SubmissionHandler Contract
- Allow hunters to submit encrypted bug reports with proof-of-concept
- Generate unique submission IDs for tracking
- Enforce submission rules, like time limits and non-duplication checks

### ValidationDAO Contract
- Token-weighted voting on submission validity by staked validators
- Proposal creation for disputes or appeals
- Quorum requirements and voting periods for fair assessments

### PayoutEscrow Contract
- Hold escrowed bounty funds until validation completes
- Automatic distribution of rewards to approved hunters
- Refund mechanisms for invalid submissions or unused bounties

---

## Installation

1. Install [Clarinet CLI](https://docs.hiro.so/clarinet/getting-started)
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/cyberbounty.git
   ```
3. Run tests:
    ```bash
    npm test
    ```
4. Deploy contracts:
    ```bash
    clarinet deploy
    ```

## Usage

Each smart contract operates independently but integrates with others for a complete bounty hunting workflow. Refer to individual contract documentation for function calls, parameters, and usage examples.

## License

MIT License