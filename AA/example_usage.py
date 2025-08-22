from web3 import Web3
from eth_account import Account
import requests
import json

w3 = Web3(Web3.HTTPProvider('https://rpc.sepolia.org'))
account = Account.from_key('YOUR_PRIVATE_KEY')  # Replace with your EOA private key
smart_account_address = 'YOUR_SMART_ACCOUNT_ADDRESS'  # From deploy.py
paymaster_address = 'YOUR_PAYMASTER_ADDRESS'  # From deploy.py

# ERC-20 transfer callData (e.g., USDC on Sepolia)
erc20_address = '0x1c7D4B196Cb0C7B01d064914d8180e9a690979ae'  # Example USDC on Sepolia
transfer_data = w3.eth.contract(abi=load_contract_abi('artifacts/IERC20.json')).encodeABI(
    'transfer', ['0xRECIPIENT_ADDRESS', w3.to_wei(1, 'mwei')]
)

# Construct UserOperation
user_op = {
    'sender': smart_account_address,
    'nonce': 0,  # Query SmartAccount for nonce
    'initCode': '0x',  # Only for first op if deploying
    'callData': w3.eth.contract(abi=load_contract_abi('artifacts/SmartAccount.json')).encodeABI('execute', [erc20_address, 0, transfer_data]),
    'callGasLimit': 100000,
    'verificationGasLimit': 100000,
    'preVerificationGas': 21000,
    'maxFeePerGas': w3.eth.gas_price,
    'maxPriorityFeePerGas': w3.eth.gas_price // 2,
    'signature': '0x',  # Sign with EOA
    'paymasterAndData': paymaster_address + '0x'
}

# Sign UserOperation
user_op_hash = w3.keccak(text=json.dumps(user_op))  # Simplified hash
user_op['signature'] = account.sign_message(w3.eth.account.message_to_bytes(user_op_hash)).signature.hex()

# Submit to bundler
response = requests.post('http://localhost:8000/api/submit_op', json=user_op)
op_hash = response.json()['op_hash']
print(f"Submitted UserOperation: {op_hash}")

# Check status
status = requests.get(f'http://localhost:8000/api/status/{op_hash}').json()
print(f"Status: {status}")