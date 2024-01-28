//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract JointBankAccount {
    //Storage variables to store unique ids for account and withdraw requests
    uint public nextAccountId;
    uint public withdrawId;

    //Structs
    struct Account {
        address[] owners;
        uint balance;
        mapping(uint => WithdrawRequest) withdraws;
    }

    struct WithdrawRequest {
        address userRequesting;
        uint amount;
        uint approvals;
        mapping(address => bool) ownerApproval;
        bool approved;
    }

    //Mappings
    mapping(uint => Account) accountsMap;
    mapping(address => uint[]) userAccounts;

    //Events
    event AccountCreated(
        address[] indexed owners,
        uint accountId,
        uint timestamp
    );

    event WithdrawRequested(
        address userRequestingWithdraw,
        uint amount,
        uint indexed accountId,
        uint indexed withdrawRequestId,
        uint timestamp
    );

    event DepositAmount(address indexed depositer, uint indexed amount);

    event WithdrawCompleted(uint indexed withdrawId, uint timestamp);

    //Modifiers
    modifier accountOwner(uint accountId) {
        uint userAccLength = userAccounts[msg.sender].length;
        bool isOwner;
        for (uint i; i < userAccLength; i++) {
            if (userAccounts[msg.sender][i] == accountId) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "Sorry, you are not the owner of this account");
        _;
    }

    modifier sufficientBalance(uint amount, uint accountId) {
        require(
            accountsMap[accountId].balance >= amount,
            "The account has insufficient balance"
        );
        _;
    }

    modifier validApprover(
        address approver,
        uint accountId,
        uint withdrawId
    ) {
        //Check whether given user has not already approved the request
        require(
            !accountsMap[accountId].withdraws[withdrawId].ownerApproval[
                approver
            ],
            "You have already approved this request."
        );
        //Check if the request is valid
        require(
            accountsMap[accountId].withdraws[withdrawId].userRequesting !=
                address(0),
            "You are trying to approve an invalid withdraw request"
        );
        //Stop the withraw requester from approving his own request
        require(
            accountsMap[accountId].withdraws[withdrawId].userRequesting ==
                msg.sender,
            " You cannot approve your own request"
        );
        //Stop user from approving a request that has already been approved
        require(
            !accountsMap[accountId].withdraws[withdrawId].approved,
            "This request is already approved."
        );
        _;
    }

    modifier canWithdraw(
        address user,
        uint accountId,
        uint withdrawId
    ) {
        //Check if withdraw is approved
        require(
            accountsMap[accountId].withdraws[withdrawId].approved,
            "This request is not yet approved"
        );
        //Check if user trying to withdraw is the one who requested for it
        require(
            accountsMap[accountId].withdraws[withdrawId].userRequesting == user,
            " You did not request for this withdraw"
        );
        _;
    }

    //Functions that change state

    //Create a new Account
    function createAccount(address[] memory otherOwners) external {
        //Store new account id;
        uint id = nextAccountId;
        //Increment nextAccountId;
        nextAccountId += 1;
        //Create a new array of length one more than the length of the array otherOwners
        address[] memory accOwners = new address[](otherOwners.length + 1);
        //Assign the user creating the contract as the last account Owner
        accOwners[otherOwners.length] = msg.sender;
        //Loop over otherOwners and assign every owner to our temp array
        for (uint i; i < otherOwners.length; i++) {
            accOwners[i] = otherOwners[i];
            //Get the number of accounts associated to this user and proceed only if it's less than 3
            uint numOfAccountsUserisPartOf = userAccounts[otherOwners[i]]
                .length;
            if (numOfAccountsUserisPartOf == 3) {
                revert("A given user can only be part of 3 accounts at max");
            } else {
                userAccounts[otherOwners[i]].push(id);
            }
        }
        accountsMap[id].owners = accOwners;
        emit AccountCreated(accOwners, id, block.timestamp);
    }

    //Deposit money into an existing account
    function depositAmount(
        uint depositAccountId
    ) external payable accountOwner(depositAccountId) {
        accountsMap[depositAccountId].balance += msg.value;
        emit DepositAmount(msg.sender, msg.value);
    }

    //Request money withdrawal from an existing account
    function requestWithdraw(
        uint amount,
        uint withdrawAccountId
    )
        external
        accountOwner(withdrawAccountId)
        sufficientBalance(amount, withdrawAccountId)
    {
        uint id = withdrawId;
        WithdrawRequest storage withdrawRequest = accountsMap[withdrawAccountId]
            .withdraws[id];
        withdrawRequest.userRequesting = msg.sender;
        withdrawRequest.amount = amount;
        withdrawId++;
        emit WithdrawRequested(
            msg.sender,
            amount,
            withdrawAccountId,
            id,
            block.timestamp
        );
    }

    //Approve withdraw request
    function approveWithdraw(
        uint accountId,
        uint withdrawId
    )
        external
        accountOwner(accountId)
        validApprover(msg.sender, accountId, withdrawId)
    {
        WithdrawRequest storage withdrawRequest = accountsMap[accountId]
            .withdraws[withdrawId];
        withdrawRequest.approvals += 1;
        withdrawRequest.ownerApproval[msg.sender] = true;
        uint numberOfOwners = accountsMap[accountId].owners.length;
        if (withdrawRequest.approvals == numberOfOwners - 1) {
            withdrawRequest.approved = true;
        }
    }

    //Withdraw money
    function withdraw(
        uint accountId,
        uint withdrawId
    ) external canWithdraw(msg.sender, accountId, withdrawId) {
        uint amount = accountsMap[accountId].withdraws[withdrawId].amount;
        require(
            accountsMap[accountId].balance >= amount,
            "Insufficient balance"
        );
        accountsMap[accountId].balance -= amount;
        delete accountsMap[accountId].withdraws[withdrawId];
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "There was a problem in withdrawing");
        emit WithdrawCompleted(withdrawId, block.timestamp);
    }

    //Get calls

    //Get all accounts associated to given user
    function getAccounts() external view returns (uint[] memory) {
        return userAccounts[msg.sender];
    }

    //Get approvals
    function getApprovals(
        uint accountId,
        uint withdrawId
    ) external view returns (uint) {
        return accountsMap[accountId].withdraws[withdrawId].approvals;
    }

    //Get owners of a given account
    function getOwners(
        uint accountId
    ) external view returns (address[] memory) {
        return accountsMap[accountId].owners;
    }

    //Get account balance
    function getAccountBalance(uint accountId) external view returns (uint) {
        return accountsMap[accountId].balance;
    }
}
