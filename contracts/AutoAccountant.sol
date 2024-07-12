
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;


import "./EthVesting.sol";
import "./Staking.sol";

contract AutoAccountant{
    address public companyAddress;
    EthVesting public ethVesting;
    Staking public staking;
    
    constructor(address payable  ethVestingAddress, address payable stakingAddress) {
        companyAddress = msg.sender;
        ethVesting = EthVesting(ethVestingAddress);
        staking = Staking(stakingAddress);
    }

    bool public checkCalculationSalary; //проверка, был ли выполнен рассчет для зп перед отправкой денег
    bool public checkCalculationStaking; //проверка, был ли выполнен рассчет для стейкинга перед отправкой денег
    uint public salarySum; //запишу сюда сколько переводить работнику
    uint public stakingSum;//запишу сюда сколько переводить в стейкинг
    address public employee; //адресс получателя, в нашем случае работника


    event Replenishment(address indexed _from, uint _amount, uint _timestamp);
    event listOfCalculatedSalaries(address indexed employee, uint  _timestamp, uint rate, uint hoursWorked, uint hoursSick, uint percentageSickRate, uint stakingPercentrage);
    event WhoWasPaid(address indexed _to, uint _amount, uint _timestamp);

    function pay()public payable{
        emit Replenishment(msg.sender, msg.value, block.timestamp);
    }
    receive() external payable {pay();}


    //Расчет заработной платы на основе ставки, отработанных часов, больничного и так далее
    function SalaryCalculation(
        uint rate, //ставка работника в единицах wei
        uint hoursWorked, //количество отработанных часов
        uint hoursSick, //количество часов на частично/полностью оплачивааемом больничном
        uint percentageSickRate, //размер больничной ставки в виде процента от основной
        uint stakingPercentrage, //процент от заработной платы, который отправляется на стейкинг
        address _employee //адресс получателя, в нашем случае это адрес нашего работника
    )external  onlyOwner
    {
        //Проверяем на корректность введенные пользователем данные, при ошибке отправляем определенное сообщение
        require(_employee!=address(0), "ERROR! The |employee| value must not be zero!");
        require(rate>0, "ERROR! The value in the |rate| field must be greater than 0!");
        require(
            percentageSickRate<=100 && percentageSickRate>=0 
            && stakingPercentrage<=100 && stakingPercentrage>=0, 
            "ERROR! Enter the percentages from 0 to 100 inclusive!"
        );
        

        //Проведение расчетов на основе полученных данных
        uint _salarySum_base = rate * hoursWorked;
        uint _salarySum_sick = (rate*percentageSickRate*hoursSick)/100;
        uint _salarySum = (_salarySum_base + _salarySum_sick)* (100-stakingPercentrage) / 100;
        uint _stakingSum = ((_salarySum_base + _salarySum_sick) * stakingPercentrage)/100;

        //Присваиваем полученные значения глобальным переменным и проверяем, корректно ли присвоились
        salarySum = _salarySum;
        stakingSum = _stakingSum;
        employee = _employee;
        require(salarySum == _salarySum && stakingSum == _stakingSum, "ERROR! DON'T SEND MONEY!!");


        //Записываем данные в события и присваиваем булевым переменным истиное значение, подтверждающее корректность данных
        emit listOfCalculatedSalaries(_employee, block.timestamp, rate, hoursWorked, hoursSick, percentageSickRate, stakingPercentrage);
        checkCalculationSalary = true;
        checkCalculationStaking = true;
    }


    //отправка части заработной платы сотруднику на основе расчетов
    function _sendSalaryToEmployee(address _employee, uint _salarySum, bool _chekCalculationSalary) internal onlyOwner{
        address payable _employeeWallet = payable (_employee);
        require(_chekCalculationSalary == true, "No DATA to send salary!");
        _employeeWallet.transfer(_salarySum);
        emit WhoWasPaid(_employee, _salarySum, block.timestamp);
    }
    function sendSalaryToEmployee() external onlyOwner{
        _sendSalaryToEmployee(employee, salarySum, checkCalculationSalary);
        checkCalculationSalary = false;
        salarySum = 0;
    }


    //отрпавка части заработной платы в стейкинг, возврат денег со стейкинга
    function sendSalaryToStaking()external onlyOwner{
        staking.stake(employee, stakingSum);
        checkCalculationStaking = false;
        stakingSum = 0;
    }

    function releaseStaked() external {
        staking.withdraw(msg.sender);
    }



    //Добавление сотрудника в вестинг и работа с ним
    function sendToVesting(address _employee, uint _amount, uint64 _duration) external onlyOwner {
        ethVesting.addEmployee(_employee, _amount, uint64(block.timestamp), _duration);
        //31,536,000 - год в секундах
    }
    function releaseVested() external {
        ethVesting.release(msg.sender);
    }


    //используемые в коде собственные модификаторы
    modifier onlyOwner(){//собственный модификатор 
        require(msg.sender == companyAddress, "You are not an owner!");
        _; //обязательная приписка
    }
}