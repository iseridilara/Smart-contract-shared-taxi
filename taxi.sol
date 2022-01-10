pragma solidity ^0.5.0;


contract sharedTaxi {
    
    
    
    struct TaxiDriver {
        address payable driverAddr;
        uint driverSalary;
        uint lastSalaryPayment; //Last salary payment
    }
    
     struct ProposedCar {
        bytes32 id;
        uint price;
        uint offerValidTime;
        
        uint8 positiveVoteNum;
        mapping (address => bool) voted;
    }
    
    struct DriverProposal {
        address payable addr;
        uint driverSalary;
        
        uint8 positiveVoteNum;
        mapping (address => bool) voted;
    }
    
    
    mapping (address => uint) public balances;
    
    address payable public carDealer;
    address public manager;
    address payable[] public participants;
    TaxiDriver public driver; //Current driver.
    
    mapping (address => bool) public checkParticipant;

    uint public expenseTime; 
    uint public feeOfParticipation;
    bytes32 public ownedCar;
    
    uint public profitDistributionTime; 
    uint public expenseCost;

    ProposedCar public carForSale; // The car which is selled by carDealer
    ProposedCar public repurchasedCar; // The car which is wanted to buy by carDealer
    DriverProposal public driverForHire;
 
    uint public lastExpenseTime; //Last maintenance.
    uint public lastProfitDist; //Last dividend payment
    
    
    //modifiers for other methods
    
    modifier onlyParticipants()
    {
        require(checkParticipant[msg.sender] == true, "Just participants can call this function.");
        _;
        
    }
    
    modifier onlyManager()
    {
        require(msg.sender == manager, "Just manager can call this function.");
        _;
        
    }
    
    modifier onlyDriver()
    {
        require(msg.sender == driver.driverAddr, "Just driver can call this function.");
        _;
        
    }
    
    modifier onlyDealer()
    {
        require(msg.sender == carDealer, "Just car dealer can call this function.");
        _;
        
    }
    
    modifier canJoin ()
    {
        require(participants.length < 9, "A maximum of 9 participants are allowed by system.");
        _;
        
    }
    
    modifier validOffer(uint validTime)
    {
        require(validTime > now, "The offer has expired.");
        _;
        
    }

    modifier greaterThenHalf(uint8 vote)
    {
        require(vote > participants.length / 2, "There are not enough approve votes.");
        _;
        
    }

    
    /// @param _expenseCost is the parameter that represents car maintenance cost
    /// @param _expenseTime  is the parameter that represents time interval for car maintenance
    /// @param _profitDistTime  is the parameter that represents time interval for dividend sharing
    /// @param _participationFee is the join fee for contract and this value is given as a parameter to the constructor of this contarct
    /// @notice this constructor sets the parameters that are defined above 
    constructor(uint _expenseCost , uint _expenseTime , uint _profitDistTime , uint _participationFee ) public
    {
        manager = msg.sender;
        expenseTime = _expenseTime;
        expenseCost = _expenseCost;
        feeOfParticipation = _participationFee;
        profitDistributionTime = _profitDistTime;
        
        lastProfitDist = now;
        
    }

    /// @notice Firstly, function checks person can join because more than nine participants are not accepted . Then join() checks person exist in the participants array. 
    function join() public payable canJoin
    {
        require(!checkParticipant[msg.sender], " You can not join again.You are already a participant.");
        require(msg.value >= feeOfParticipation, "Participation fee is higher than the ether you send.");
        checkParticipant[msg.sender] = true;
        participants.push(msg.sender);
    }
    
 
    /// @notice This function sets the _carDealer to carDealer variable.
    function setCarDealer(address payable _carDealer) public onlyManager
    {
        carDealer = _carDealer;
    }

    
    /// @param price is the parameter that represents how much ethers is required to buy it
    /// @param carId is the parameter that represents id of the car
    /// @param validTime is the parameter that represents the date when offer ends.
    /// @notice Function is for proposing a car to partners. And it uses onlyDealer modifier.
    function carProposeToBusiness(uint price , bytes32 carId, uint validTime) public onlyDealer 
    {
        carForSale = ProposedCar({
            id: carId,
            price: price,
            offerValidTime: validTime,
            positiveVoteNum: 0
        });
    }

    /// @notice  participants can vote to buy it.However the offer time must note have passed. Each participants can vote only one time.
    /// @notice  onlyParticipants and validOffer modifiers are used in this function
    function approvePurchaseCar() public onlyParticipants validOffer(carForSale.offerValidTime)
    {
        require(!carForSale.voted[msg.sender], "You can not vote.You already voted.");
        carForSale.voted[msg.sender] = true;
        carForSale.positiveVoteNum += 1;
    }

    /// @notice If there are enough votes in contract and the offer time is not pass, this function sets owned car and transfers ethers to carDealer.
    /// @notice  greaterThenHalf and validOffer modifiers are used in this function
    function purchaseCar() public onlyManager greaterThenHalf(carForSale.positiveVoteNum) validOffer(carForSale.offerValidTime)
    {
        require(carForSale.id != ownedCar, "You already bought that car.");
        require(address(this).balance > carForSale.price, "The contract does not have enough ether.");
        ownedCar = carForSale.id;
        lastExpenseTime = now;
        carDealer.transfer(carForSale.price);
        delete carForSale;
        deleteMapping(0);
    }

    
    /// @param carId is the parameter that represents id of car . This id must  be the same  ownedCar.
    /// @param price  is the parameter that represents how much ethers is required to buy it
    /// @param validTime  is the parameter that represents the date when offer ends.
    /// @notice Function for proposing to buy car from partnership.And only Dealer can call this function. 
    function repurchaseCarPropose(bytes32 carId, uint price, uint validTime) public onlyDealer
    {
        require(carId == ownedCar, "There is no car with this id.");
        repurchasedCar = ProposedCar({
            id: carId,
            price: price,
            offerValidTime: validTime,
            positiveVoteNum: 0
        });
    }

    /// @notice Participants can vote to sell it.However the offer time must note have passed. Each participants can vote only one time.
    /// @notice only participants can call this function.
    function approveSellPropose() public onlyParticipants validOffer(repurchasedCar.offerValidTime)
    {
        require(!repurchasedCar.voted[msg.sender], "You already voted.");
        repurchasedCar.voted[msg.sender] = true;
        repurchasedCar.positiveVoteNum += 1;
    }

    /// @notice If offer time is not pass and enough votes and msg.value is enough, function deleteMapping ownedCar and repurchasedCar.
    /// @notice only Dealer can call this function.
    function repurchaseCar() public payable onlyDealer validOffer(repurchasedCar.offerValidTime) greaterThenHalf(repurchasedCar.positiveVoteNum) 
    {
        require(msg.value == repurchasedCar.price, "You have to send enough amount to buy.");
        delete ownedCar;
        delete repurchasedCar;
        deleteMapping(1);
    }

    
    /// @param driver_addr is the parameter that represents address of the driver
    /// @param driverSalary  is the parameter that represents the how much ethers will paid to the driver.
    /// @notice Function for proposing a driver to partnership and only Manager can call this function.
    function proposeDriver(address payable driver_addr, uint driverSalary) public onlyManager
    {
        driverForHire = DriverProposal({
            addr:driver_addr,
            driverSalary:driverSalary,
            positiveVoteNum: 0
        });
    }

    /// @notice Function for approve driver . Each participant can vote only one time.
    /// @notice only participants can call this function.
    function approveDriver() public onlyParticipants
    {
        require(!driverForHire.voted[msg.sender], "You already voted.");
        driverForHire.voted[msg.sender] = true;
        driverForHire.positiveVoteNum += 1;
    }

    /// @notice If there is no driver and there is enough vote , this function sets new driver.
    /// @notice only manager can call this function.
    function setDriver() public onlyManager greaterThenHalf(driverForHire.positiveVoteNum)
    {
        require(driver.driverAddr == address(0x0), "You already have a driver.");
        driver = TaxiDriver({
            driverAddr: driverForHire.addr,
            driverSalary: driverForHire.driverSalary,
            lastSalaryPayment: now
        });
        delete driverForHire;
        deleteMapping(2);
    }

    /// @notice If there is a driver, manager can fire driver with this function. This function transfers salary of driver.
    /// @notice only manager can call this function.
    function fireDriver() public onlyManager
    {
        require(driver.driverAddr != address(0x0), "There is no driver to fire!");
        driver.driverAddr.transfer(driver.driverSalary);
        delete driver;
    }

    /// @notice Function gets payment from customer
    function getCharge() public payable{}

    /// @notice Function releases driver's salary. It works if the driver is present and it is time to pay the salary. 
    /// @notice only manager can call this function.
    function releaseSalary() public onlyManager
    {
        require(driver.driverAddr != address(0x0), "There is no driver to pay!");
        require(now > driver.lastSalaryPayment + 4 weeks, "not a mounth has passed");
        driver.lastSalaryPayment = now;
        balances[driver.driverAddr] += driver.driverSalary;
    }

    /// @notice Driver can withdraw his salary. Only Driver can call this function.
    function getSalary() public onlyDriver
    {
        require(balances[driver.driverAddr]>0, "You do not have any ether in contract.");
        uint driverBalance = balances[driver.driverAddr];
        balances[driver.driverAddr] = 0;
        driver.driverAddr.transfer(driverBalance);
    }

    /// @notice This function transfers maintenance cost to carDealer, if maintenance time of it comes and partnership has a car.
    /// @notice Only manager can call this function.
    function PayCarExpenses() public onlyManager
    {
        require(ownedCar != 0, "You don't have any car.");
        require(now > lastExpenseTime + expenseTime, "It isn't time for car maintenance.");
        lastExpenseTime = now;
        carDealer.transfer(expenseCost);
    }

    /// @notice Function check  balance and time. If two of them are enough, function shares the dividends.
    /// @notice For calculation dividends, 6 next driver salary and 1 next maintenance cost are decreased from profit.
    /// @notice Only manager can call this function.
    function payDividend() public onlyManager
    {
        require(now > lastProfitDist + profitDistributionTime, "It is not time to distribute dividends.");
        uint dividend = address(this).balance - (expenseCost + 6 * driver.driverSalary) / participants.length;
        require(dividend > 0, "There are not enough ether");
        lastProfitDist = now;
        for(uint8 i; i < participants.length; i++){
            balances[participants[i]] += dividend;
        }
    }

    /// @notice Participants can withdraw theirs ethers.
    /// @notice Only participants can call this function.
    function getDividend() public onlyParticipants
    {
        require(balances[msg.sender] > 0, "You don't have any ether.");
        uint balance = balances[msg.sender];
        balances[msg.sender] = 0;
        msg.sender.transfer(balance);
    }

    function () external{}

    /// @notice This function deletes the mapping in a structure after it is deleted.
    /// @param m To choose which mappings to clear.
    function deleteMapping(uint8 m) private {
        for(uint8 j = 0; j < participants.length; j++){
            if(m==0)
            {
                
                delete carForSale.voted[participants[j]];
            }
            else if(m==1)
            {
                
                delete repurchasedCar.voted[participants[j]];
            }
            else
            {
                
                delete driverForHire.voted[participants[j]];
            }
        }
    }


    
}