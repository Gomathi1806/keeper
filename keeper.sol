//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

// KeeperCompatible.sol imports the functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
//2000000000000000000
/// This contract handles the main logic for CrypChip
contract CrypChip is KeeperCompatibleInterface {

    using Counters for Counters.Counter;
    Counters.Counter private gIds;
    Counters.Counter private eIds;

    uint interval = 5;
    uint lastTimeStamp;

    enum ExpenseStatus {
        ACTIVE,
        ONGOING,
        SETTLED
    }

    struct ExpenseGroup {
        uint gId;
        address owner;
        address[] participants;
    }

    struct Expense {
        uint gId;
        uint eId;
        address payer;
        address creator;

        //The total remaining expense to be paid out - will be split equally between participants
        uint totalExpense;
        address[] participants;
        ExpenseStatus status;
        mapping(address => uint) balances;
        mapping(address => bool) settled;
    }

    //Total number of groups
    mapping(uint => ExpenseGroup) groups;

    //Total expenses
    mapping(uint => Expense) public expenses;

    //How many expenses are there in a group
    mapping(uint => uint[]) groupExpenses;

    //How many expense groups is an inidividual a part of
    mapping(address => ExpenseGroup[]) expenseGroups;

    constructor() {
        lastTimeStamp = block.timestamp;
    }

    function createGroup(address[] memory participants) public returns(bool){

        //Generating a group ID every time a new group is created
        gIds.increment();
        uint id = gIds.current();

        //Create a new group
        ExpenseGroup storage newGroup = groups[id];
        newGroup.gId = id;
        newGroup.owner = msg.sender;
        newGroup.participants = participants;

        //Mapping groups to a user
        expenseGroups[msg.sender].push(newGroup);

        return true;
    }


    function addExpense(uint _gId, address _payer, uint _totalExpense, address[] memory _participants) public returns(uint){
        require(groups[_gId].gId != 0, "Group doesn't exist");
        require(_payer != address(0), "Payer cannot be zero address");
        require(_totalExpense > 0, "Total expenses should be greater than 0");
        require(_participants. length > 0, "Number of participants to split with, cannot be zero");

        //Generating a expense ID every time a new expense is created
        eIds.increment();
        uint id = eIds.current();
        Expense storage newExpense = expenses[id];
        newExpense.gId = _gId;
        newExpense.eId = id;
        newExpense.payer = _payer;
        newExpense.creator = msg.sender;
        newExpense.totalExpense = _totalExpense;
        newExpense.participants = _participants;
        newExpense.status = ExpenseStatus.ACTIVE;

        //Create mappings of users and their balances
        uint numParticipants = _participants.length;
        uint expensePerPerson = _totalExpense/numParticipants;
  
        
        //Populating the balances and the settles(true/false) mapping
        for(uint i = 0; i < numParticipants; i++){
            newExpense.balances[_participants[i]] = expensePerPerson;
            newExpense.settled[_participants[i]] = false;
        }

        //Mapping the expenses of a group
        groupExpenses[_gId].push(id);

        return expensePerPerson;

    }

    //Each individual can call this function to settle up their debts(it's a payable function)
    function settleUp(uint expenseId) public payable returns(ExpenseStatus status){
        Expense storage newExpense = expenses[expenseId];
        address to = newExpense.payer;
        uint amount = newExpense.balances[msg.sender];
        uint counter = 0;

        require(newExpense.status != ExpenseStatus.SETTLED, "This expense is no longer valid.");
        require(amount > 0, "No balances left in this expense.");
        require(msg.value >= amount, "You have not sent enough money to settle,");

        payable(to).transfer(amount);
        newExpense.settled[msg.sender] = true;

        for(uint i = 0; i < newExpense.participants.length; i++){
            if(newExpense.settled[newExpense.participants[i]] == true){
                counter++;
            }
        }

        // if (counter >= creatorArray.length) {
        //     counter = 0;
        // }

        if(counter == newExpense.participants.length){
            newExpense.status = ExpenseStatus.SETTLED;
        }
        else {
            newExpense.status = ExpenseStatus.ONGOING;
        }

        return expenses[expenseId].status;

    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */){        
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }    


    function performUpkeep(
        bytes calldata /* performData */
        ) external override {
            
        lastTimeStamp = block.timestamp;

        //SettleUp();
    }


    /// ALL THE GET CALLS ARE BELOW

    //Returns the group IDs that the user is a part of
    function getGroups(address user) public view returns(ExpenseGroup[] memory) {
        return expenseGroups[user];
    }

    //Returns all the expense IDs of a particular group
    function getExpensesFromGroup(uint groupId) public view returns(uint[] memory) {
        return groupExpenses[groupId];
    }

    //Unable to return expenses due to nested mappings - need to find a solution
    // function getExpense(uint expenseId) public returns(Expense memory) {
    //     Expense memory oldExpense = expenses[expenseId];
    //     return oldExpense;
    // }

}
