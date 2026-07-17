export const BondedAssertionAbi = [
  {
    "type": "function",
    "name": "assertTruth",
    "inputs": [
      {
        "name": "claim",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "asserter",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "callbackRecipient",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "escalationPolicy",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "liveness",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "currency",
        "type": "address",
        "internalType": "contract IERC20"
      },
      {
        "name": "bond",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assertionId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "disputeAssertion",
    "inputs": [
      {
        "name": "assertionId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getAssertion",
    "inputs": [
      {
        "name": "assertionId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct IBondedAssertion.Assertion",
        "components": [
          {
            "name": "claim",
            "type": "bytes",
            "internalType": "bytes"
          },
          {
            "name": "asserter",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "callbackRecipient",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "escalationPolicy",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "currency",
            "type": "address",
            "internalType": "contract IERC20"
          },
          {
            "name": "bond",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "expirationTime",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "status",
            "type": "uint8",
            "internalType": "enum IBondedAssertion.Status"
          },
          {
            "name": "truthful",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "overridden",
            "type": "bool",
            "internalType": "bool"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "overrideResolution",
    "inputs": [
      {
        "name": "assertionId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "truthful",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "settleAssertion",
    "inputs": [
      {
        "name": "assertionId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "AssertionDisputed",
    "inputs": [
      {
        "name": "assertionId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "disputer",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AssertionMade",
    "inputs": [
      {
        "name": "assertionId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "claim",
        "type": "bytes",
        "indexed": false,
        "internalType": "bytes"
      },
      {
        "name": "asserter",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "callbackRecipient",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "escalationPolicy",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "bond",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "expirationTime",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AssertionOverridden",
    "inputs": [
      {
        "name": "assertionId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "truthful",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AssertionSettled",
    "inputs": [
      {
        "name": "assertionId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "truthful",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      },
      {
        "name": "bondRecipient",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SafeERC20FailedOperation",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ]
  }
] as const;
