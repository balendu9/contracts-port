from web3 import Web3
from eth_account import Account
import json

w3 = Web3(Web3.HTTPProvider('https://rpc.sepolia.org'))
account = Account.from_key('YOUR_PRIVATE_KEY')  # Replace with your private key

def load_contract_abi(file_path: str):
    with open(file_path, 'r') as f:
        return json.load(f)['abi']

def deploy_contract(abi, bytecode, *constructor_args):
    contract = w3.eth.contract(abi=abi, bytecode=bytecode)
    tx = contract.constructor(*constructor_args).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 2000000,
        'gasPrice': w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, account.key)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    return receipt.contractAddress

# Load ABIs and bytecodes (assumes Hardhat compilation)
smart_account_abi = load_contract_abi('artifacts/SmartAccount.json')
smart_account_bytecode = '0x...'  # Replace with compiled bytecode
paymaster_abi = load_contract_abi('artifacts/Paymaster.json')
paymaster_bytecode = '0x...'  # Replace with compiled bytecode

# Deploy SmartAccount
owner = '0xYOUR_EOA_ADDRESS'  # Replace with EOA address
entry_point = '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789'
smart_account_address = deploy_contract(smart_account_abi, smart_account_bytecode, owner, entry_point)
print(f"SmartAccount deployed at: {smart_account_address}")

# Deploy Paymaster
paymaster_address = deploy_contract(paymaster_abi, paymaster_bytecode, account.address, entry_point)
print(f"Paymaster deployed at: {paymaster_address}")

# Fund Paymaster
tx = {
    'to': entry_point,
    'value': w3.to_wei(0.1, 'ether'),
    'data': w3.eth.contract(abi=load_contract_abi('artifacts/IEntryPoint.json')).encodeABI('depositTo', [paymaster_address]),
    'nonce': w3.eth.get_transaction_count(account.address),
    'gas': 100000,
    'gasPrice': w3.eth.gas_price
}
signed_tx = w3.eth.account.sign_transaction(tx, account.key)
tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
print(f"Paymaster funded: {tx_hash.hex()}")