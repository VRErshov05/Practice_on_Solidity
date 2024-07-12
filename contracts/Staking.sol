
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract Staking {
    address public owner;
    uint256 public dailyReward = 335000000000000000; // 0.335 ETH в день в качестве вознаграждения

    struct Stakeholder {
        uint256 stakedAmount; // Сумма стейкинга
        uint256 rewardDebt; // Накопленные вознаграждения
        uint256 lastStakeTime; // Время последнего стейка
        mapping(uint256 => uint256) dailyStakedAmounts; // История стейкинга по дням
    }
    // В контракте Staking
    function getStakeHolderAmount(address _employee) external view returns (uint256) {
        Stakeholder storage staker = stakeholders[_employee];
        return (staker.stakedAmount);
    }

    mapping(address => Stakeholder) public stakeholders; // Маппинг пользователей и их стейкинга
    uint256 public totalStakedAmount; // Общая сумма стейкинга
    mapping(uint256 => uint256) public dailyTotalStakedAmounts; // История общей суммы стейкинга по дням

    event StakeIncreased(address indexed employee, uint256 additionalAmount); // Событие увеличения стейка
    event StakeWithdrawn(address indexed employee, uint256 amount); // Событие снятия стейка
    event RewardPaid(address indexed employee, uint256 amount); // Событие выплаты вознаграждения

    constructor() {
        owner = msg.sender;
    }

    function pay() public payable {}

    receive() external payable { pay(); }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    // Функция для стейкинга пользователем
    function stake(address _employee, uint256 amount) external onlyOwner {
        require(_employee != address(0), "Invalid _employee address!"); // Проверка адреса
        require(amount > 0, "The stake amount must be greater than 0!"); // Проверка суммы стейка

        Stakeholder storage staker = stakeholders[_employee];
        uint256 currentDay = block.timestamp / 1 days;

        if (staker.stakedAmount > 0) {
            uint256 pendingReward = calculateReward(_employee); // Рассчитываем накопленные награды
            staker.rewardDebt += pendingReward; // Добавляем награды к накопленным
        } else {
            staker.lastStakeTime = block.timestamp; // Устанавливаем время последнего стейка
        }

        staker.stakedAmount += amount; // Увеличиваем сумму стейкинга
        staker.dailyStakedAmounts[currentDay] += amount; // Обновляем историю стейкинга по дням
        totalStakedAmount += amount; // Увеличиваем общую сумму стейкинга
        dailyTotalStakedAmounts[currentDay] += amount; // Обновляем общую сумму стейкинга по дням

        emit StakeIncreased(_employee, amount); // Выпускаем событие увеличения стейка
    }

    // Функция для снятия стейкинга и получения вознаграждения
    function withdraw(address _employee) external onlyOwner {
        Stakeholder storage staker = stakeholders[_employee];
        require(staker.stakedAmount > 0, "There is no amount of staking to withdraw!"); // Проверка наличия стейка

        uint256 reward = calculateReward(_employee) + staker.rewardDebt; // Рассчитываем и суммируем награды
        require(reward > 0, "There is no reward available"); // Проверка наличия наград

        uint256 amount = staker.stakedAmount; // Записываем сумму стейка
        staker.stakedAmount = 0; // Обнуляем сумму стейка
        staker.rewardDebt = 0; // Обнуляем накопленные награды
        totalStakedAmount -= amount; // Уменьшаем общую сумму стейкинга
        uint256 currentDay = block.timestamp / 1 days;
        dailyTotalStakedAmounts[currentDay] -= amount; // Уменьшаем общую сумму стейкинга по дням

        payable(_employee).transfer(amount + reward); // Переводим сумму стейка и награды пользователю

        emit StakeWithdrawn(_employee, amount); // Выпускаем событие снятия стейка
        emit RewardPaid(_employee, reward); // Выпускаем событие выплаты награды
    }

    // Функция для расчета вознаграждения пользователя
    function calculateReward(address _employee) public view returns (uint256) {
        Stakeholder storage staker = stakeholders[_employee];
        if (staker.stakedAmount == 0) {
            return 0; // Если стейкинг отсутствует, возвращаем 0
        }

        uint256 totalReward = 0; // Общая награда
        uint256 currentDay = block.timestamp / 1 days; // Текущий день
        uint256 startDay = staker.lastStakeTime / 1 days; // День последнего стейка

        for (uint256 day = startDay; day <= currentDay; day++) {
            uint256 _employeeShare = (staker.dailyStakedAmounts[day] * 100) / dailyTotalStakedAmounts[day]; // Доля пользователя
            uint256 reward = (dailyReward * _employeeShare) / 100; // Награда за день
            totalReward += reward; // Суммируем награду
        }

        return totalReward; // Возвращаем общую награду
    }

    // Функция для получения текущего стейкинга пользователя
    function getStakedBalance(address _employee) external view returns (uint256) {
        return stakeholders[_employee].stakedAmount; // Возвращаем текущий стейкинг пользователя
    }

    // Модификатор доступа только для владельца контракта
    modifier onlyOwner() {
        require(msg.sender == owner, "You are not an owner!"); // Проверка, что вызывающий является владельцем
        _;
    }
}