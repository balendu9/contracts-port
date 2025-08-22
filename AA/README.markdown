# Account Abstraction Service for Sepolia

This project implements an Account Abstraction (AA) service on the Sepolia testnet, enabling users to create smart wallets and send gasless transactions using a Paymaster with configurable policies. The system includes Solidity smart contracts (SmartAccount and Paymaster), a Python-based bundler/relayer API using FastAPI, and a job worker for processing UserOperations. It supports a per-address daily limit of 5 operations and provides REST API endpoints for submitting operations, checking status, and listing history.

## Table of Contents
- [Overview](#overview)
- [Components](#components)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Deployment](#deployment)
- [Usage](#usage)
- [API Endpoints](#api-endpoints)
- [Project Structure](#project-structure)
- [Assumptions and Limitations](#assumptions-and-limitations)
- [Security Considerations](#security-considerations)
- [Future Improvements](#future-improvements)
- [License](#license)

## Overview
This project implements an ERC-4337-compliant Account Abstraction service for the Sepolia testnet. It allows users to:
- Create a SmartAccount (AA-compatible wallet) owned by an EOA.
- Send gasless ERC-20 transfers sponsored by a Paymaster with a daily limit of 5 operations per address.
- Submit UserOperations via a REST API, which are bundled and relayed to the EntryPoint contract.
- Monitor operation status and history.

The system uses:
- **Solidity**: SmartAccount and Paymaster contracts.
- **Python/FastAPI**: Bundler/relayer API and job worker.
- **SQLite**: Stores UserOperations and transaction receipts.
- **Sepolia EntryPoint**: Standard ERC-4337 EntryPoint at `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789`.

## Components
1. **SmartAccount (`SmartAccount.sol`)**:
   - An AA-compatible wallet contract that validates UserOperations and executes transactions.
   - Owned by an EOA, interacts with the EntryPoint contract.
   - Supports signature validation and transaction execution.

2. **Paymaster (`Paymaster.sol`)**:
   - Sponsors gas fees for UserOperations.
   - Enforces a daily limit of 5 operations per address.
   - Deposits ETH to the EntryPoint for gas sponsorship.

3. **Bundler/Relayer API (`bundler.py`)**:
   - FastAPI-based REST API for submitting UserOperations, checking status, and listing history.
   - Simulates, signs, and bundles UserOperations to the EntryPoint's `handleOps` function.
   - Stores operations and receipts in SQLite.

4. **Job Worker**:
   - Integrated into `bundler.py` as an async task (`process_op`).
   - Processes queued UserOperations, submits them to the blockchain, and updates receipt status.

5. **Deployment Script (`deploy.py`)**:
   - Deploys SmartAccount and Paymaster contracts to Sepolia.
   - Funds the Paymaster via the EntryPoint's `depositTo` function.

6. **Example Usage Script (`example_usage.py`)**:
   - Demonstrates creating a SmartAccount and submitting a gasless ERC-20 transfer.

## Prerequisites
- **Node.js and npm**: For Hardhat to compile Solidity contracts.
- **Python 3.8+**: For the bundler and scripts.
- **Sepolia ETH**: For deploying contracts and funding the Paymaster.
- **Sepolia RPC**: Access to a Sepolia node (e.g., Infura, Alchemy, or public RPC `https://rpc.sepolia.org`).
- **Private Key**: An EOA private key with Sepolia ETH for deployment and testing.

## Installation
1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd aa-service-sepolia
   ```

2. **Install Node.js Dependencies**:
   ```bash
   npm install -g hardhat
   npm install @openzeppelin/contracts
   ```

3. **Install Python Dependencies**:
   ```bash
   pip install fastapi uvicorn web3 eth-account pydantic
   ```

4. **Set Up Environment Variables**:
   Create a `.env` file in the project root:
   ```bash
   PRIVATE_KEY=your_private_key_here
   RPC_URL=https://rpc.sepolia.org
   ```
   Replace `your_private_key_here` with your Sepolia-funded EOA private key.

5. **Compile Solidity Contracts**:
   - Create a Hardhat project:
     ```bash
     npx hardhat init
     ```
   - Place `SmartAccount.sol` and `Paymaster.sol` in the `contracts/` directory.
   - Compile contracts:
     ```bash
     npx hardhat compile
     ```
   - Copy the generated ABIs and bytecodes from `artifacts/contracts/` to use in `deploy.py`.

## Deployment
1. **Update `deploy.py`**:
   - Replace `YOUR_PRIVATE_KEY` with your EOA private key (or load from `.env`).
   - Update `smart_account_bytecode` and `paymaster_bytecode` with the compiled bytecodes from Hardhat.
   - Update the `IEntryPoint.json` ABI path if needed.

2. **Deploy Contracts**:
   ```bash
   python deploy.py
   ```
   - This deploys the SmartAccount and Paymaster contracts.
   - Funds the Paymaster with 0.1 ETH (adjust as needed).
   - Outputs the deployed contract addresses.

3. **Save Contract Addresses**:
   - Note the `SmartAccount` and `Paymaster` addresses from the deployment output.
   - Update `example_usage.py` with these addresses.

## Usage
1. **Start the Bundler**:
   ```bash
   python bundler.py
   ```
   - The FastAPI server runs on `http://localhost:8000`.
   - Initializes an SQLite database (`ops.db`) for storing operations.

2. **Run Example Usage**:
   - Update `example_usage.py`:
     - Set `YOUR_PRIVATE_KEY` (EOA private key).
     - Set `YOUR_SMART_ACCOUNT_ADDRESS` and `YOUR_PAYMASTER_ADDRESS` from deployment.
     - Update `RECIPIENT_ADDRESS` for the ERC-20 transfer (e.g., USDC on Sepolia).
   - Run the script:
     ```bash
     python example_usage.py
     ```
   - This submits a gasless ERC-20 transfer and prints the operation hash and status.

3. **Interact with the API**:
   - Use tools like `curl` or Postman to interact with the REST API (see [API Endpoints](#api-endpoints)).

## API Endpoints
The bundler provides the following REST API endpoints:

1. **Submit UserOperation**:
   - **Endpoint**: `POST /api/submit_op`
   - **Body**: JSON object with UserOperation fields (see `bundler.py` for schema).
   - **Response**: `{ "op_hash": "<uuid>" }`
   - **Example**:
     ```bash
     curl -X POST http://localhost:8000/api/submit_op -H "Content-Type: application/json" -d '{"sender":"0x...","nonce":0,...}'
     ```

2. **Get Operation Status**:
   - **Endpoint**: `GET /api/status/{op_hash}`
   - **Response**: `{ "op_hash": "<uuid>", "status": "pending|completed|failed", "receipt": {...} }`
   - **Example**:
     ```bash
     curl http://localhost:8000/api/status/<op_hash>
     ```

3. **List Operation History**:
   - **Endpoint**: `GET /api/history`
   - **Response**: List of operation statuses.
   - **Example**:
     ```bash
     curl http://localhost:8000/api/history
     ```

## Project Structure
```
aa-service-sepolia/
├── contracts/
│   ├── SmartAccount.sol
│   ├── Paymaster.sol
├── artifacts/  # Generated by Hardhat
├── bundler.py
├── deploy.py
├── example_usage.py
├── ops.db  # SQLite database (created on first run)
├── README.md
├── .env
├── package.json  # For Hardhat
```

## Assumptions and Limitations
- **EntryPoint**: Uses the standard Sepolia EntryPoint at `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789`.
- **Gas Estimation**: Uses static gas values in `bundler.py` and `example_usage.py`. Production systems should implement dynamic gas estimation.
- **Simulation**: Simplified UserOperation simulation. Add `eth_call` validation for production.
- **Database**: Uses SQLite for simplicity. Use PostgreSQL or similar for production.
- **Job Worker**: Integrated into `bundler.py` as an async task. Use a dedicated queue (e.g., Redis) for scalability.
- **ERC-20 Example**: Assumes a USDC contract on Sepolia (`0x1c7D4B196Cb0C7B01d064914d8180e9a690979ae`). Update for other tokens.

## Security Considerations
- **Private Keys**: Store private keys securely in environment variables or a secrets manager. Never hardcode in scripts.
- **Paymaster Funding**: Ensure the Paymaster is sufficiently funded to cover gas costs.
- **Signature Validation**: The SmartAccount uses ECDSA; consider additional validation for production.
- **Rate Limiting**: The Paymaster enforces a 5 ops/day limit per address. Add allowlists or other policies as needed.
- **API Security**: Add authentication and rate limiting to the FastAPI endpoints in production.

## Future Improvements
- Implement proper UserOperation simulation using `eth_call`.
- Add a queue system (e.g., Redis or RabbitMQ) for the job worker.
- Support additional Paymaster policies (e.g., allowlists, ERC-20 prepaid model).
- Add a minimal Next.js or Flask dashboard for UX.
- Implement dynamic gas estimation for UserOperations.
- Add error handling and retries for failed transactions.

## License
MIT License. See [LICENSE](LICENSE) for details.