const { expect } = require("chai");
const { ethers } = require("hardhat");
const { network } = require("hardhat");


describe("AutoAccountant", function () {
  let autoAccountant;
  let ethVesting;
  let staking;
  let owner;
  let employee;
  let employee2;
  let employee3;

  beforeEach(async function () {
    [owner, employee, employee2, employee3] = await ethers.getSigners();

    // Развертывание контракта EthVesting
    const EthVesting = await ethers.getContractFactory("EthVesting");
    ethVesting = await EthVesting.deploy();
    await ethVesting.waitForDeployment();
    //ethVesting.address = await ethVesting.getAddress();
    console.log(`EthVesting deployed at: ${await ethVesting.getAddress()}`);

    // Развертывание контракта Staking
    const Staking = await ethers.getContractFactory("Staking");
    staking = await Staking.deploy();
    await staking.waitForDeployment();
    //staking.address = await staking.getAddress();
    console.log(`Staking deployed at: ${await staking.getAddress()}`);

    // Развертывание контракта AutoAccountant
    const AutoAccountant = await ethers.getContractFactory("AutoAccountant");
    autoAccountant = await AutoAccountant.deploy(await ethVesting.getAddress(), await staking.getAddress());
    await autoAccountant.waitForDeployment();
    //autoAccountant.address = await staking.getAddress();
    console.log(`AutoAccountant deployed at: ${await autoAccountant.getAddress()}`);

    await ethVesting.setOwner(await autoAccountant.getAddress()); 
    await staking.setOwner(await autoAccountant.getAddress());
  });

  it("Must calculate the salary correctly", async function () {
    // Проверка адресов перед вызовом функции
    expect(await ethVesting.getAddress()).to.not.be.null;
    expect(await staking.getAddress()).to.not.be.null;
    expect(await autoAccountant.getAddress()).to.not.be.null;
    expect(employee.address).to.not.be.null;


    await autoAccountant.SalaryCalculation(
      1000, // ставка
      40, // отработанные часы
      10, // часы на больничном
      50, // процент больничной ставки
      20, // процент для стейкинга
      employee.address // адрес сотрудника
    );

    const salarySum = await autoAccountant.salarySum();
    const stakingSum = await autoAccountant.stakingSum();

    const checkCalculationSalary = await autoAccountant.checkCalculationSalary();
    const checkCalculationStaking = await autoAccountant.checkCalculationStaking();

    expect(salarySum).to.equal(36000); // 40*1000 + 10*1000*0.5 = 45000. 45000 * 0.8 = 36000
    expect(stakingSum).to.equal(9000); // 45000 * 0.2

    expect(checkCalculationSalary).to.equal(true); 
    expect(checkCalculationStaking).to.equal(true);
  });

  it("Must send the salary correctly", async function () {
    // Выполняем рассчет зарплаты
    await autoAccountant.SalaryCalculation(
      100000000000000000n, // ставка
      100, // отработанные часы
      0, // часы на больничном
      0, // процент больничной ставки
      90, // процент для стейкинга
      employee.address // адрес сотрудника
    );
    const tx = await owner.sendTransaction({
      to: await autoAccountant.getAddress(),
      value: 100000000000000000000n
    });
    await tx.wait();

    const initialEmployeeBalance = await ethers.provider.getBalance(employee.address);
    //console.log(`initialEmployeeBalance: ${initialEmployeeBalance}`);
    expect(initialEmployeeBalance).to.equal(10000000000000000000000n);

    await autoAccountant.sendSalaryToEmployee();

    const finalEmployeeBalance = await ethers.provider.getBalance(employee.address);
    // Проверяем, что баланс увеличился на ожидаемую сумму
    const expectedSalary = 10001000000000000000000n; // ожидаемый баланс
    expect(finalEmployeeBalance).to.equal(expectedSalary);
    
  });

  it("Must send the salary to staking correctly", async function () {
    // Выполняем расчет зарплаты
    await autoAccountant.SalaryCalculation(
      100000000000000000n, // ставка
      100, // отработанные часы
      0, // часы на больничном
      0, // процент больничной ставки
      10, // процент для стейкинга
      employee.address // адрес сотрудника
    );

    const tx = await owner.sendTransaction({
      to: await autoAccountant.getAddress(),
      value: 100000000000000000000n
    });
    await tx.wait();


    await autoAccountant.sendSalaryToStaking();

    const finalStakerInfo = await staking.getStakeHolderAmount(employee.address);
  
    // Проверяем, что стейкинг сумма увеличилась на ожидаемую сумму
    const expectedStakingAmount = 1000000000000000000n; // ожидаемая сумма для стейкинга
    expect(finalStakerInfo).to.equal(expectedStakingAmount);
  });

  it("Must correctly put Ethereum on westing", async function () {

    const tx = await owner.sendTransaction({
      to: await autoAccountant.getAddress(),
      value: 100000000000000000000n
    });
    await tx.wait();

    await autoAccountant.sendToVesting(
      employee.address, // адрес сотрудника
      1000000000000000000n, // ставка
      31536000 // время вестинга
    );

    // Проверяем, что вестинг сумма увеличилась на ожидаемую сумму
    const VestingTotalAmount = await ethVesting.getVestingTotalAmount(employee.address);
    const expectedVestingAmount = 1000000000000000000n; // ожидаемая сумма для вестинга
    expect(VestingTotalAmount).to.equal(expectedVestingAmount);

    // Проверяем корректность времени стейкинга
    const VestingDuration = await ethVesting.getVestingDuration(employee.address);
    const expectedVestingDuration = 31536000; // ожидаемое время вестинга
    expect(VestingDuration).to.equal(expectedVestingDuration);
  });

  //Проверяет, правильно ли работает вестинг. Смотрит чтобы точную сумму переводил через 30 секунд из 60, и через 130 секунд чтобы выводил не больше 6000.
  it("Must correctly release Ethereum westing", async function () {

    const tx = await owner.sendTransaction({
      to: await autoAccountant.getAddress(),
      value: 100000000000000000000n
    });
    await tx.wait();

    const tx2 = await owner.sendTransaction({
      to: await ethVesting.getAddress(),
      value: 100000000000000000000n
    });
    await tx2.wait();

    await autoAccountant.sendToVesting(
      employee.address, // адрес сотрудника
      60000000000000000000n, // ставка
      60 // время вестинга
    );
    const firstEmployeeBalance = await ethers.provider.getBalance(employee.address);
    console.log(`FirstEmployeeBalance ${firstEmployeeBalance}`);

    async function increaseTime(seconds) {
      await network.provider.send("evm_increaseTime", [seconds]);
      await network.provider.send("evm_mine");
    }
    // Проверяем, что вестинг сумма увеличилась на ожидаемую сумму
    const VestingTotalAmount = await ethVesting.getVestingTotalAmount(employee.address);
    const expectedVestingAmount = 60000000000000000000n; // ожидаемая сумма для вестинга
    expect(VestingTotalAmount).to.equal(expectedVestingAmount);

    // Проверяем корректность времени стейкинга
    const VestingDuration = await ethVesting.getVestingDuration(employee.address);
    const expectedVestingDuration = 60; // ожидаемое время вестинга
    expect(VestingDuration).to.equal(expectedVestingDuration);


    //нужно промотать время на 30 секунд
    await increaseTime(29);

    const VestingEmployeeConnect = autoAccountant.connect(employee);
    await VestingEmployeeConnect.releaseVested(); 
    const VestingReleased = await ethVesting.getVestingReleased(employee.address);
    const expectedVestingReleased = 30000000000000000000n; // ожидаемое количество выпущенной валюты через 30 секунд
    expect(VestingReleased).to.equal(expectedVestingReleased);

  

    //нужно перемотать время на 100 секунд
    await increaseTime(99);
    
    await VestingEmployeeConnect.releaseVested(); 
    const VestingReleased2 = await ethVesting.getVestingReleased(employee.address);
    const expectedVestingReleased2 = 60000000000000000000n; // ожидаемое количество выпущенной валюты через 130 секунд
    expect(VestingReleased2).to.equal(expectedVestingReleased2);


  });

  it("Must correctly release Ethereum staking", async function () {

    const tx = await owner.sendTransaction({
      to: await autoAccountant.getAddress(),
      value: 1000000000000000000000n
    });
    await tx.wait();

    const tx2 = await owner.sendTransaction({
      to: await staking.getAddress(),
      value: 1000000000000000000000n
    });
    await tx2.wait();

    const firstEmployee2Balance = await ethers.provider.getBalance(employee2.address);
    console.log(`FirstEmployeeBalance 1: ${firstEmployee2Balance}`);

    const firstEmployee3Balance = await ethers.provider.getBalance(employee3.address);
    console.log(`FirstEmployeeBalance 1: ${firstEmployee3Balance}`);


    async function increaseTime(seconds) {
      await network.provider.send("evm_increaseTime", [seconds]);
      await network.provider.send("evm_mine");
    }

    await autoAccountant.SalaryCalculation(
      100000000000000000n, // ставка
      100, // отработанные часы
      0, // часы на больничном
      100, // процент больничной ставки
      10, // процент для стейкинга
      employee2.address // адрес сотрудника
    );
    await autoAccountant.sendSalaryToStaking();
    const finalStakerInfo = await staking.getStakeHolderAmount(employee2.address);
    // Проверяем, что стейкинг сумма увеличилась на ожидаемую сумму
    const expectedStakingAmount = 1000000000000000000n; // ожидаемая сумма для стейкинга
    expect(finalStakerInfo).to.equal(expectedStakingAmount);


    
    increaseTime(86399);
    
    await autoAccountant.SalaryCalculation(
      100000000000000000n, // ставка
      100, // отработанные часы
      0, // часы на больничном
      100, // процент больничной ставки
      10, // процент для стейкинга
      employee3.address // адрес сотрудника
    );
    await autoAccountant.sendSalaryToStaking();
    console.time('Transaction time for test 6');
    const finalStakerInfo1 = await staking.getStakeHolderAmount(employee3.address);
    // Проверяем, что стейкинг сумма увеличилась на ожидаемую сумму
    const expectedStakingAmount1 = 1000000000000000000n; // ожидаемая сумма для стейкинга
    expect(finalStakerInfo1).to.equal(expectedStakingAmount1);

    
    increaseTime(86399);
    
    console.timeEnd('Transaction time for test 6');

    const StakingEmployee2Connect = autoAccountant.connect(employee2);
    await StakingEmployee2Connect.releaseStaked();

    const StakingEmployee3Connect = autoAccountant.connect(employee3);
    await StakingEmployee3Connect.releaseStaked();
    

    const finalEmployee2ReleasedStaked = await staking.getStakeHolderlastReleasedAmount(employee2.address);
    expect(finalEmployee2ReleasedStaked).to.equal(1537844150000000000n); //((4150000000000*86400) + (4150000000000*86400/2)) + 4150000000000(2 секунды на выполнение проги) + 10^18 = 1537844150000000000

    const finalEmployee3ReleasedStaked = await staking.getStakeHolderlastReleasedAmount(employee3.address);
    expect(finalEmployee3ReleasedStaked).to.equal(1179284150000000000n); //(4150000000000*86400/2) + 4150000000000(2 секунды на выполнение проги) + 10^18 = 1179280000000000000

    
  });
});