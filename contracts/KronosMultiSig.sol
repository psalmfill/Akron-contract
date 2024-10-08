// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract KronosMultiSig {
    // Structure to define a transaction proposal
    struct Transaction {
        address target; // Target address to execute the transaction
        bytes data; // Transaction data (function call, etc.)
        uint value; // ETH value to be transferred with the transaction
        uint256 confirmations; // Number of confirmations received for the transaction
        bool executed; // Status to check if the transaction is executed
        address proposedBy; // Address of the owner who proposed the transaction
    }

    // Mapping to store all transactions by ID
    mapping(uint => Transaction) public transactions;

    // Mapping to track confirmations for each transaction by each owner
    mapping(uint => mapping(address => bool)) public confirmations;

    // Mapping to check if an address is an owner
    mapping(address => bool) public isOwner;

    // Array to store the list of owners
    address[] public owners;

    // Number of confirmations required to execute a transaction
    uint public requiredConfirmations;

    // Counter to track the total number of transactions proposed
    uint public transactionCounter;

    // Events to track transactions and state changes
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

    /**
     * @dev Constructor that sets up the owners and required confirmations.
     * @param _owners The addresses of the owners.
     * @param _requiredConfirmations The number of confirmations required to execute a transaction.
     */
    constructor(address[] memory _owners, uint _requiredConfirmations) {
        require(_owners.length > 0, "Owners required");
        require(
            _requiredConfirmations > 0 &&
                _requiredConfirmations <= _owners.length,
            "Invalid number of required confirmations"
        );

        // Set the owners and initialize the owners mapping
        for (uint256 i; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[_owners[i]], "Owner not unique");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        requiredConfirmations = _requiredConfirmations;
    }

    // Modifier to ensure only an owner can perform certain actions
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    // Modifier to ensure that only the contract itself can call a function (for adding/removing owners)
    modifier onlySelf() {
        require(
            msg.sender == address(this),
            "Only the contract can call this function"
        );
        _;
    }

    // Modifier to check that a transaction is not already executed
    modifier notExecuted(uint actionId) {
        require(!transactions[actionId].executed, "Action already executed");
        _;
    }

    /**
     * @dev Proposes a new transaction to be confirmed by the owners.
     * @param target The target address to call.
     * @param data The data for the transaction (function call, etc.).
     * @param value The ETH value to send along with the transaction.
     */
    function proposeTransaction(
        address target,
        bytes memory data,
        uint value
    ) external onlyOwner {
        Transaction storage transaction = transactions[transactionCounter];
        transaction.target = target;
        transaction.data = data;
        transaction.proposedBy = msg.sender;
        transaction.value = value;

        emit TransactionProposed(transactionCounter, target, data);
        transactionCounter++;
    }

    /**
     * @dev Approves a proposed transaction by an owner. Once enough confirmations are received, the transaction is executed.
     * @param transactionId The ID of the transaction to confirm.
     */
    function approveTransaction(
        uint transactionId
    ) external onlyOwner notExecuted(transactionId) {
        require(!confirmations[transactionId][msg.sender], "Action confirmed");

        confirmations[transactionId][msg.sender] = true;
        Transaction storage transaction = transactions[transactionId];
        transaction.confirmations++;

        emit TransactionConfirmed(transactionId, msg.sender);

        // Execute the transaction if enough confirmations are met
        if (transaction.confirmations >= requiredConfirmations) {
            executeTransaction(transactionId);
        }
    }

    /**
     * @dev Revokes an owner's approval for a transaction.
     * @param transactionId The ID of the transaction to revoke approval from.
     */
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

    /**
     * @dev Executes a confirmed transaction once the required number of confirmations is reached.
     * @param actionId The ID of the transaction to execute.
     */
    function executeTransaction(
        uint actionId
    ) public onlyOwner notExecuted(actionId) {
        Transaction storage transaction = transactions[actionId];

        // Ensure the transaction has enough confirmations
        require(
            transaction.confirmations >= requiredConfirmations,
            "low confirmations"
        );

        // Attempt to execute the transaction
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

    /**
     * @dev Allows the contract itself to add a new owner.
     * This function can only be called by the contract itself (multi-signature governance).
     * @param newOwner The address of the new owner to be added.
     */
    function addOwner(address newOwner) external onlySelf {
        require(!isOwner[newOwner], "Already an owner");
        isOwner[newOwner] = true;
        owners.push(newOwner);
    }

    /**
     * @dev Allows the contract itself to remove an existing owner.
     * This function can only be called by the contract itself (multi-signature governance).
     * @param owner The address of the owner to be removed.
     */
    function removeOwner(address owner) external onlySelf {
        require(isOwner[owner], "Not an owner");
        isOwner[owner] = false;

        // Remove owner from the owners array
        for (uint256 i; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
    }

    /**
     * @dev Allows the contract itself to update the number of required confirmations.
     * This function can only be called by the contract itself (multi-signature governance).
     * @param newRequiredConfirmations The new number of confirmations required.
     */
    function setRequiredConfirmations(
        uint newRequiredConfirmations
    ) external onlySelf {
        require(
            newRequiredConfirmations >= 0 &&
                newRequiredConfirmations <= owners.length,
            "Invalid number of required confirmations"
        );
        requiredConfirmations = newRequiredConfirmations;
    }

    /**
     * @dev Allows the contract to receive ETH deposits. Emits a Deposit event with the sender and the current balance.
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @dev Allows the contract itself to withdraw funds.
     * This function can only be called by the contract itself (multi-signature governance).
     * @param to The address to send the withdrawn Ether to.
     * @param amount The amount of Ether to withdraw.
     */
    function withdrawBalance(address payable to, uint amount) external onlySelf {
        require(address(this).balance >= amount, "Insufficient balance");

        (bool success, ) = to.call{value: amount}("");
        require(success, "Withdrawal failed");
    }
}
