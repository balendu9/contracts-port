import json
import random
import time
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from web3 import Web3
from web3.exceptions import ContractLogicError

# ------------------------------
# Helper: Load ABIs from files
# ------------------------------
def load_abi(file_path):
    with open(file_path, 'r') as f:
        return json.load(f)

ARB_ABI = load_abi('abis/ArbitrageContract.json')
ROUTER_ABI = load_abi('abis/Router.json')
ERC20_ABI = load_abi('abis/ERC20.json')
PAIR_ABI = load_abi('abis/Pair.json')

# ------------------------------
# Load contract addresses
# ------------------------------
with open('addresses.json', 'r') as f:
    addresses = json.load(f)

# ------------------------------
# Connect to blockchain
# ------------------------------
w3 = Web3(Web3.HTTPProvider('https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY'))  # Replace with your key
account = w3.eth.account.from_key('your_private_key')  # Replace with your private key

# ------------------------------
# Initialize contracts
# ------------------------------
arb_contract = w3.eth.contract(address=addresses['arbitrageContract'], abi=ARB_ABI)
token_a = w3.eth.contract(address=addresses['tokenA'], abi=ERC20_ABI)
token_b = w3.eth.contract(address=addresses['tokenB'], abi=ERC20_ABI)
dex1_router = w3.eth.contract(address=addresses['dex1Router'], abi=ROUTER_ABI)
dex2_router = w3.eth.contract(address=addresses['dex2Router'], abi=ROUTER_ABI)
pair1 = w3.eth.contract(address=addresses['pair1'], abi=PAIR_ABI)
pair2 = w3.eth.contract(address=addresses['pair2'], abi=PAIR_ABI)

# ------------------------------
# Helper: Send transaction
# ------------------------------
def send_tx(contract, function_name, params, value=0):
    tx = contract.functions[function_name](*params).build_transaction({
        'from': account.address,
        'value': value,
        'gas': 2000000,
        'gasPrice': w3.to_wei('5', 'gwei'),
        'nonce': w3.eth.get_transaction_count(account.address),
    })
    signed_tx = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    return receipt

# ------------------------------
# Calculate arbitrage opportunity
# ------------------------------
def calculate_opportunity(loan_amount, fee_rate=0.0009):
    reserves1 = pair1.functions.getReserves().call()
    reserve_a1, reserve_b1 = reserves1[0], reserves1[1]

    reserves2 = pair2.functions.getReserves().call()
    reserve_a2, reserve_b2 = reserves2[0], reserves2[1]

    # A -> B on DEX1
    amount_b_out = (loan_amount * reserve_b1) / (reserve_a1 + loan_amount) * 0.997

    # B -> A on DEX2
    amount_a_out = (amount_b_out * reserve_a2) / (reserve_b2 + amount_b_out) * 0.997

    fee = loan_amount * fee_rate
    profit = amount_a_out - loan_amount - fee
    slippage = (amount_a_out - (loan_amount + fee)) / (loan_amount + fee) if profit > 0 else 0
    return profit, slippage

# ------------------------------
# Adjust liquidity
# ------------------------------
def adjust_liquidity(dex_router, add=True, amount_a=1000*10**18):
    amount_b_delta = 100*10**18
    # Approve tokens
    send_tx(token_a, 'approve', (dex_router.address, amount_a + amount_b_delta))
    send_tx(token_b, 'approve', (dex_router.address, amount_a + amount_b_delta))

    if add:
        amount_b = random.randint(900, 1100) * 10**18
        send_tx(dex_router, 'addLiquidity', (
            addresses['tokenA'], addresses['tokenB'], amount_a, amount_b, 0, 0, account.address, int(time.time()) + 600
        ))
    else:
        lp_balance = 100*10**18  # Replace with real query if needed
        send_tx(dex_router, 'removeLiquidity', (
            addresses['tokenA'], addresses['tokenB'], lp_balance, 0, 0, account.address, int(time.time()) + 600
        ))

# ------------------------------
# Execute arbitrage
# ------------------------------
def execute_arbitrage(loan_amount=100*10**18, min_profit=1*10**18):
    try:
        receipt = send_tx(arb_contract, 'startArbitrage', (loan_amount, min_profit))
        logs = arb_contract.events.ArbitrageExecuted().process_receipt(receipt)
        if logs:
            event = logs[0]['args']
            return True, event['profit'], event['gasUsed'], 0
        return False, 0, 0, 0
    except ContractLogicError:
        return False, 0, 0, -0.05

# ------------------------------
# Simulate multiple cycles
# ------------------------------
def simulate_cycles(num_cycles=100):
    results = []
    for cycle in range(num_cycles):
        adjust_liquidity(dex1_router, add=random.choice([True, False]))
        adjust_liquidity(dex2_router, add=random.choice([True, False]))

        profit_est, slippage_est = calculate_opportunity(100*10**18)

        if profit_est > 0:
            success, profit, gas_used, slippage = execute_arbitrage()
        else:
            success, profit, gas_used, slippage = False, profit_est, 0, slippage_est

        results.append({
            'cycle': cycle,
            'success': success,
            'profit': profit / 10**18,
            'gas_used': gas_used,
            'slippage': slippage,
            'risk_note': 'Slippage failure' if not success else 'None'
        })

        time.sleep(1)

    df = pd.DataFrame(results)
    success_rate = df['success'].mean() * 100
    total_profit = df['profit'].sum()
    avg_gas = df['gas_used'].mean()

    print(f"Success Rate: {success_rate}%")
    print(f"Total Profit: {total_profit} TokenA")
    print(f"Avg Gas: {avg_gas}")
    print(df.head())

    df['cum_profit'] = df['profit'].cumsum()
    plt.plot(df['cycle'], df['cum_profit'])
    plt.title('Cumulative Profit Over Cycles')
    plt.savefig('performance.png')
    print("Performance graph saved as performance.png")

# ------------------------------
# Test risk scenarios
# ------------------------------
def test_risks():
    adjust_liquidity(dex1_router, add=False)
    execute_arbitrage()  # Expect failure due to high slippage

# ------------------------------
# Main execution
# ------------------------------
if __name__ == "__main__":
    simulate_cycles(100)
    test_risks()
