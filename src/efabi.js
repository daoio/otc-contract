const efabi = [
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "name": "contractIds",
    "outputs": [
      {
        "internalType": "contract Escrow",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_tokenAddr",
        "type": "address"
      },
      {
        "internalType": "address payable",
        "name": "_userETH",
        "type": "address"
      },
      {
        "internalType": "address payable",
        "name": "_userERC20",
        "type": "address"
      }
    ],
    "name": "createEscrow",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]