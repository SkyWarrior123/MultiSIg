// SPDX-License-Identifier: MIT
// The code below is a MultiSig Wallet representation which can be used by any user to create by just passing the owners and the number of confirmations required by them.

pragma solidity ^0.8.20;

// error code
error ZeroAddress();

contract MultiSig {
    
    //////////// EVENTS ///////////////////

    event Deposit (
        address indexed sender,
        uint amount,
        uint balance
    );

    event SubmitTransaction (
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );

    event ConfirmTransaction (
        address indexed owner,
        uint indexed txIndex
    );

    event RevokeConfirmation (
        address indexed owner,
        uint indexed txIndex
    );

    event ExecuteTransaction (
        address indexed owner,
        uint indexed txIndex
    );

    ////////////// STATE VARIABLES //////////////////
    address[] public owners;
    
    uint public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfiramtions;
    }

    Transaction[] public transactions;

   
    ///////////////////////////////// MAPPING ////////////////////////////////////////////
    /* A mapping from txIndex => owner => bool */
    mapping (uint => mapping(address => bool)) public isConfirmed;

    /* A mapping to keep records of the owner of the current tx initiiation */
    mapping (address => bool) public isOwner;

    //////////////// MODIFIERS ////////////////////////////

    modifier onlyOwner() {
        require (isOwner[msg.sender], "only owner can access the function");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx not exists ");
        _;
    }

    modifier nonExecuted (uint _txIndex) {
        require (!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed (uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx alreeadt cnfirmed");
        _;
    }

    ///////////////// CONSTRUCTOR //////////////////////

    constructor(
        address[] memory _owners,
        uint _numConfirmationsRequired
    ) 
    {
        require(_owners.length > 0, "owners required");
        require(
            _numConfirmationsRequired > 0 &&
            _numConfirmationsRequired <= _owners.length, 
            "confirmations requried should be less than owners"
        );
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            if (owner == address(0)) {
                revert ZeroAddress();
            }
            require(!isOwner[owner], "owner not unique" );

            isOwner[owner] = true;
            owners.push(owner);
        }
    }

    receive() external payable { 
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }



    //////// FUNCTION //////////////////

    function submitTransaction (
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction ({
                to: _to,
                value: _value,
                data:  _data,
                executed: false,
                numConfiramtions: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction (
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) nonExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfiramtions += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) nonExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(transaction.numConfiramtions >= numConfirmationsRequired, "not enough confirmations");

        transaction.executed = true;
        (bool success, ) = transaction.to.call{ value: transaction.value }(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(
        uint _txIndex
    ) public {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "cannot revoke unconfirmed tx");
        transaction.numConfiramtions -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    ///////////// READ FUNCTIONS //////////////////

    function getTransaction(
        uint _txIndex
    ) public view returns (
        address to,
        uint value,
        bytes memory data,
        bool executed,
        uint numConfirmations
    ) {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfiramtions
        );
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionsCount() public view returns (uint) {
        return transactions.length;
    }


}
