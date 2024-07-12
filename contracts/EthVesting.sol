
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;


contract EthVesting{
    address public owner;
    struct Employee {
        uint256 totalAmount;
        uint256 released;
        uint64 startTime;
        uint64 duration;
    }
    function getVestingTotalAmount(address _employee) external view returns (uint256) {
        Employee memory employee = employees[_employee];
        return (employee.totalAmount);
    }
    function getVestingDuration(address _employee) external view returns (uint256) {
        Employee memory employee = employees[_employee];
        return (employee.duration);
    }
    function getVestingReleased(address _employee) external view returns (uint256) {
        Employee memory employee = employees[_employee];
        return (employee.startTime);
    }

    mapping(address => Employee) public employees;

    event EtherReleased(address indexed employee, uint256 amount);

    constructor() {
        owner = msg.sender;
    }
     function pay()public payable{   
    }
    receive() external payable {pay();}

    function setOwner(address _owner) public onlyOwner{
        owner = _owner;
    }
    // Добавление сотрудника
    function addEmployee(address employee, uint256 totalAmount, uint64 startTime, uint64 duration) external onlyOwner{
        require(employees[employee].totalAmount == 0, "Employee already exists");
        employees[employee] = Employee({
            totalAmount: totalAmount,
            released: 0,
            startTime: startTime,
            duration: duration
        });
    }

    // Расчет доступных средств для выпуска
   function calculateReleasable(address employee) public view returns (uint256) {
        Employee memory emp = employees[employee];
        uint64 currentTime = uint64(block.timestamp);
        
        if (currentTime < emp.startTime) {
            return 0;
        }

        uint256 totalReleasable;
        //проверка на то, что срок закончен
        if (currentTime >= emp.startTime + emp.duration) {
            totalReleasable = emp.totalAmount;
        } else {
            totalReleasable = (emp.totalAmount * (currentTime - emp.startTime)) / emp.duration;
        }

        return totalReleasable - emp.released;
    }

    // Выпуск средств сотруднику
    function release(address _employee) external onlyOwner{
        Employee storage emp = employees[_employee];
        uint256 releasable = calculateReleasable(_employee);
        require(releasable > 0, "No releasable amount");
        
        emp.released += releasable;
        payable(_employee).transfer(releasable);

        emit EtherReleased(_employee, releasable);
    }

     modifier onlyOwner(){//собственный модификатор 
        require(msg.sender == owner, "You are not an owner!");
        _; //обязательная приписка
    }
}