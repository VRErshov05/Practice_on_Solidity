// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract Staking {
    address public owner;
    uint256 public rewardPerSecond = 4150000000000; // 4,150,000,000,000 wei в секунду

    struct Stakeholder {
        uint256 stakedAmount; // Сумма стейкинга
        uint256 rewardDebt; // Накопленные вознаграждения
        uint256 lastReleasedAmount;
    }

    //для тестов
    function getStakeHolderlastReleasedAmount(address _employee) external view returns (uint256) {
        Stakeholder memory employee = stakeholders[_employee];
        return (employee.lastReleasedAmount);
    }
    function getStakeHolderAmount(address _employee) external view returns (uint256) {
        Stakeholder memory employee = stakeholders[_employee];
        return (employee.stakedAmount);
    }

    mapping(address => Stakeholder) public stakeholders; // Маппинг пользователей и их стейкинга
    uint256 public totalStakedAmount; // Общая сумма стейкинга
    uint256 public accRewardPerShare; // Аккумулированная награда на акцию
    uint256 public lastRewardTime; // Время последнего обновления наград

    event StakeIncreased(address indexed employee, uint256 additionalAmount); // Событие увеличения стейка
    event StakeWithdrawn(address indexed employee, uint256 amount); // Событие снятия стейка
    event RewardPaid(address indexed employee, uint256 amount); // Событие выплаты вознаграждения

    constructor() {
        owner = msg.sender;
        lastRewardTime = block.timestamp; // Устанавливаем время последнего обновления наград
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

        updatePool(); // Обновляем пул наград перед внесением изменений

        Stakeholder storage staker = stakeholders[_employee];

        if (staker.stakedAmount > 0) {
            uint256 pendingReward = (staker.stakedAmount * accRewardPerShare) / 1e18 - staker.rewardDebt;
            staker.rewardDebt += pendingReward; // Обновляем накопленные награды
        }

        staker.stakedAmount += amount; // Увеличиваем сумму стейкинга
        staker.rewardDebt = (staker.stakedAmount * accRewardPerShare) / 1e18;

        totalStakedAmount += amount; // Увеличиваем общую сумму стейкинга

        emit StakeIncreased(_employee, amount); // Выпускаем событие увеличения стейка
    }

    // Функция для снятия стейкинга и получения вознаграждения
    function withdraw(address _employee) external onlyOwner {
        Stakeholder storage staker = stakeholders[_employee];
        require(staker.stakedAmount > 0, "There is no amount of staking to withdraw!");

        updatePool(); // Обновляем пул наград перед внесением изменений

        uint256 pendingReward = (staker.stakedAmount * accRewardPerShare) / 1e18 - staker.rewardDebt;
        uint256 amount = staker.stakedAmount;

        totalStakedAmount -= amount; // Уменьшаем общую сумму стейкинга

        staker.stakedAmount = 0;
        staker.rewardDebt = 0;

        payable(_employee).transfer(amount + pendingReward);
        staker.lastReleasedAmount = amount + pendingReward;

        emit StakeWithdrawn(_employee, amount);
        emit RewardPaid(_employee, pendingReward);
    }

    // Функция для обновления пула наград
    function updatePool() internal {
        if (block.timestamp <= lastRewardTime) {
            return;
        }
        if (totalStakedAmount == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        uint256 timeElapsed = block.timestamp - lastRewardTime;
        uint256 reward = timeElapsed * rewardPerSecond;

        accRewardPerShare += (reward * 1e18) / totalStakedAmount;
        lastRewardTime = block.timestamp;
    }

    // Функция для расчета вознаграждения пользователя
    function calculateReward(address _employee) public view returns (uint256) {
        Stakeholder storage staker = stakeholders[_employee];
        if (staker.stakedAmount == 0) {
            return 0; // Если стейкинг отсутствует, возвращаем 0
        }

        uint256 _accRewardPerShare = accRewardPerShare;
        if (block.timestamp > lastRewardTime && totalStakedAmount != 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime;
            uint256 reward = timeElapsed * rewardPerSecond;
            _accRewardPerShare += (reward * 1e18) / totalStakedAmount;
        }

        return (staker.stakedAmount * _accRewardPerShare) / 1e18 - staker.rewardDebt;
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
