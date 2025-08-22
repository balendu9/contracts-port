from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from web3 import Web3
import sqlite3
import json
from typing import List
import time
import asyncio
from eth_account import Account
from eth_account.signers.local import LocalAccount
import uuid

app = FastAPI()
w3 = Web3(Web3.HTTPProvider('https://rpc.sepolia.org'))
entry_point_address = '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789'
account = Account.from_key('YOUR_PRIVATE_KEY')  # Replace with your relayer private key

class UserOperation(BaseModel):
    sender: str
    nonce: int
    initCode: str
    callData: str
    callGasLimit: int
    verificationGasLimit: int
    preVerificationGas: int
    maxFeePerGas: int
    maxPriorityFeePerGas: int
    signature: str
    paymasterAndData: str

class OpStatus(BaseModel):
    op_hash: str
    status: str
    receipt: dict = None

# Database setup
def init_db():
    conn = sqlite3.connect('ops.db')
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS operations
                 (op_hash TEXT PRIMARY KEY, user_op TEXT, status TEXT, receipt TEXT, created_at INTEGER)''')
    conn.commit()
    conn.close()

init_db()

@app.post("/api/submit_op", response_model=dict)
async def submit_op(user_op: UserOperation):
    op_hash = str(uuid.uuid4())
    conn = sqlite3.connect('ops.db')
    c = conn.cursor()
    c.execute("INSERT INTO operations (op_hash, user_op, status, created_at) VALUES (?, ?, ?, ?)",
              (op_hash, json.dumps(user_op.dict()), "pending", int(time.time())))
    conn.commit()
    conn.close()
    asyncio.create_task(process_op(op_hash, user_op))
    return {"op_hash": op_hash}

async def process_op(op_hash: str, user_op: UserOperation):
    try:
        # Simulate UserOperation (simplified; add proper validation)
        op = user_op.dict()
        tx = {
            'to': entry_point_address,
            'data': encode_user_op(op),
            'gas': 1000000,  # Estimate gas properly in production
            'maxFeePerGas': op['maxFeePerGas'],
            'maxPriorityFeePerGas': op['maxPriorityFeePerGas'],
            'nonce': w3.eth.get_transaction_count(account.address),
        }
        signed_tx = w3.eth.account.sign_transaction(tx, account.key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

        # Update DB
        conn = sqlite3.connect('ops.db')
        c = conn.cursor()
        c.execute("UPDATE operations SET status = ?, receipt = ? WHERE op_hash = ?",
                  ("completed", json.dumps(dict(receipt)), op_hash))
        conn.commit()
        conn.close()
    except Exception as e:
        conn = sqlite3.connect('ops.db')
        c = conn.cursor()
        c.execute("UPDATE operations SET status = ? WHERE op_hash = ?",
                  ("failed", op_hash))
        conn.commit()
        conn.close()

@app.get("/api/status/{op_hash}", response_model=OpStatus)
async def get_status(op_hash: str):
    conn = sqlite3.connect('ops.db')
    c = conn.cursor()
    c.execute("SELECT status, receipt FROM operations WHERE op_hash = ?", (op_hash,))
    result = c.fetchone()
    conn.close()
    if not result:
        raise HTTPException(status_code=404, detail="Operation not found")
    return OpStatus(op_hash=op_hash, status=result[0], receipt=json.loads(result[1]) if result[1] else None)

@app.get("/api/history", response_model=List[OpStatus])
async def get_history():
    conn = sqlite3.connect('ops.db')
    c = conn.cursor()
    c.execute("SELECT op_hash, status, receipt FROM operations")
    results = c.fetchall()
    conn.close()
    return [OpStatus(op_hash=r[0], status=r[1], receipt=json.loads(r[2]) if r[2] else None) for r in results]

def encode_user_op(op: dict) -> str:
    # Simplified; encode UserOperation according to ERC-4337
    return "0x"  # Implement proper encoding

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)