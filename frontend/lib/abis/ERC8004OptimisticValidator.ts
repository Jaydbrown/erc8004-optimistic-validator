export const ERC8004OptimisticValidatorAbi = [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "validationRegistry_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "bondedAssertion_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "currency_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "liveness_",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "BONDED_ASSERTION",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IBondedAssertion"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "BOND_CURRENCY",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IERC20"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "LIVENESS",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "VALIDATION_REGISTRY",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IValidationRegistry"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "assertionResolvedCallback",
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
    "name": "eip712Domain",
    "inputs": [],
    "outputs": [
      {
        "name": "fields",
        "type": "bytes1",
        "internalType": "bytes1"
      },
      {
        "name": "name",
        "type": "string",
        "internalType": "string"
      },
      {
        "name": "version",
        "type": "string",
        "internalType": "string"
      },
      {
        "name": "chainId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "verifyingContract",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "salt",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "extensions",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "escalationManager",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract AgentWorkEscalationManager"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getRequest",
    "inputs": [
      {
        "name": "requestHash",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct ERC8004OptimisticValidator.RequestState",
        "components": [
          {
            "name": "status",
            "type": "uint8",
            "internalType": "enum ERC8004OptimisticValidator.RequestStatus"
          },
          {
            "name": "client",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "assertionId",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "responseURI",
            "type": "string",
            "internalType": "string"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "owner",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "proposeOutcome",
    "inputs": [
      {
        "name": "agentId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "requestHash",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "client",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "deadline",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "clientSig",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "responseURI",
        "type": "string",
        "internalType": "string"
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
    "name": "renounceOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "requestHashOfAssertion",
    "inputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "requests",
    "inputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "status",
        "type": "uint8",
        "internalType": "enum ERC8004OptimisticValidator.RequestStatus"
      },
      {
        "name": "client",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "assertionId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "responseURI",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "setEscalationManager",
    "inputs": [
      {
        "name": "escalationManager_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "transferOwnership",
    "inputs": [
      {
        "name": "newOwner",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "EIP712DomainChanged",
    "inputs": [],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "EscalationManagerSet",
    "inputs": [
      {
        "name": "escalationManager",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OutcomeProposed",
    "inputs": [
      {
        "name": "requestHash",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "assertionId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "agent",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "client",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "bond",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OutcomeResolved",
    "inputs": [
      {
        "name": "requestHash",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
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
    "name": "OwnershipTransferred",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "ECDSAInvalidSignature",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ECDSAInvalidSignatureLength",
    "inputs": [
      {
        "name": "length",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "ECDSAInvalidSignatureS",
    "inputs": [
      {
        "name": "s",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "InvalidShortString",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OwnableInvalidOwner",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "OwnableUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ]
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
  },
  {
    "type": "error",
    "name": "StringTooLong",
    "inputs": [
      {
        "name": "str",
        "type": "string",
        "internalType": "string"
      }
    ]
  }
] as const;
