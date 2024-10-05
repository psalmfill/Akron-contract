// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AkronMultiSign {
    struct Transaction {
        address target;
        bytes data;
        uint value;
        uint256 confirmations;
        bool executed;
        address proposedBy;
    }

    mapping(uint => Transaction) public transactions;
    mapping(uint => mapping(address => bool)) public confirmations;
    mapping(address => bool) public isOwner;

    address[] public owners;
    uint public requiredConfirmations;
    uint public transactionCounter;

    event TransactionProposed(uint actionId, address target, bytes data);
    event TransactionConfirmed(uint actionId, address owner);
    event TransactionConfirmationRevoked(uint actionId, address owner);
    event TransactionExecuted(
        uint actionId,
        address target,
        bytes data,
        bool status
    );
    event Deposit(address indexed sender, uint256 amount, uint256 balance);

    constructor(address[] memory _owners, uint _requiredConfirmations) {
        require(_owners.length > 0, "Owners required");
        require(
            _requiredConfirmations > 0 &&
                _requiredConfirmations <= _owners.length,
            "Invalid number of required confirmations"
        );

        for (uint256 i; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[_owners[i]], "Owner not unique");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        requiredConfirmations = _requiredConfirmations;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier onlySelf() {
        require(
            msg.sender == address(this),
            "Only the contract can call this function"
        );
        _;
    }

    modifier notExecuted(uint actionId) {
        require(!transactions[actionId].executed, "Action already executed");
        _;
    }

    function proposeTransaction(
        address target,
        bytes memory data,
        uint value
    ) external onlyOwner {
        Transaction storage transacton = transactions[transactionCounter];
        transacton.target = target;
        transacton.data = data;
        transacton.proposedBy = msg.sender;
        transacton.value = value;

        emit TransactionProposed(transactionCounter, target, data);
        transactionCounter++;
    }

    function approveTransaction(
        uint transactionId
    ) external onlyOwner notExecuted(transactionId) {
        require(!confirmations[transactionId][msg.sender], "Action confirmed");

        confirmations[transactionId][msg.sender] = true;
        Transaction storage transaction = transactions[transactionId];

        transaction.confirmations++;

        emit TransactionConfirmed(transactionId, msg.sender);

        if (transaction.confirmations >= requiredConfirmations) {
            executeTransaction(transactionId);
        }
    }

    function revokeTransactionApproval(
        uint transactionId
    ) external onlyOwner notExecuted(transactionId) {
        require(
            confirmations[transactionId][msg.sender],
            "Action not confirmed"
        );

        confirmations[transactionId][msg.sender] = false;
        Transaction storage transaction = transactions[transactionId];

        transaction.confirmations--;

        emit TransactionConfirmationRevoked(transactionId, msg.sender);
    }

    function executeTransaction(
        uint actionId
    ) public onlyOwner notExecuted(actionId) {
        Transaction storage transaction = transactions[actionId];

        require(
            transaction.confirmations >= requiredConfirmations,
            "low confirmations"
        );

        (bool success, ) = transaction.target.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Execution failed");

        transaction.executed = success;

        emit TransactionExecuted(
            actionId,
            transaction.target,
            transaction.data,
            success
        );
    }

    function addOwner(address newOwner) external onlySelf {
        require(!isOwner[newOwner], "Already an owner");
        isOwner[newOwner] = true;
        owners.push(newOwner);
    }

    function removeOwner(address owner) external onlySelf {
        require(isOwner[owner], "Not an owner");
        isOwner[owner] = false;

        // Remove owner from array
        for (uint256 i; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
}
