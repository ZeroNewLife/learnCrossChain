//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author ZeroWeb3
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each will user will have their own interest rate that is the global interest rate at the time of depositing.
 */

contract RebaseToken is ERC20 {
   /////////////////////
    // State Variables
    /////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256  currentInterestRate,uint256 newInterestRate);


    /////////////////////
    // State Variables
    /////////////////////

    uint256 private s_interestRate=5e10;  // 5% interest rate expressed in 1e18 precision (5e16 = 5%) 5e10 = 0.000005% per second
    mapping(address => uint256) public s_userInterestRate; // хранит процентную ставку пользователя
    mapping(address => uint256) public s_userLastUpdatedTimestamp; // хранит последний таймстамп обновления пользователя 
    uint256 private  constant PRESISION_FACTOR = 1e18; // precision factor for interest calculations


    /////////////////////
    // Events
    /////////////////////
    event InterestRateUpdated(uint256 newInterestRate); // событие обновления процентной ставки

    /////////////////////
    // Constructor
    /////////////////////

    constructor() ERC20("Rebase Token", "RBT") {} //инициализируем ERC20 токен с именем и символом

    /////////////////////
    // Functions
    /////////////////////
    // Тут мы переопределяем баланс пользователя с учетом накопленных процентов
    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user)*_calculateUserAcumulatedInterestLastUpdate(_user) / PRESISION_FACTOR; 
        
    }
    // Тут мы считаем накопленные проценты пользователя с момента последнего обновления
    function _calculateUserAcumulatedInterestLastUpdate(address _user) internal view returns (uint256 linearInterest) { 
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user]; // считаем время прошедшее с последнего обновления
        linearInterest =(PRESISION_FACTOR + (s_userInterestRate[_user] * timeElapsed)); // считаем линейный интерес
      
    }

    //Тут мы можем менять процентную ставку только в сторону уменьшения
    function setInterestRate(uint256 _newRate) public {
        if (_newRate <s_interestRate) {  // проверяем что новая ставка меньше текущей
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate,_newRate); // выбрасываем ошибку если новая ставка больше текущей
        }
        s_interestRate = _newRate; // обновляем глобальную процентную ставку
        emit InterestRateUpdated(_newRate); // эмитируем событие
    }
     // Тут мы начисляем проценты пользователю при минте  
     // и обновляем его процентную ставку и таймстамп
     
    function mint(address _to, uint256 _amount) public {
        _mintAccuredInterest(_to); //начисляем проценты перед минтом
        s_userInterestRate[_to] = s_interestRate; //обновляем процентную ставку пользователя
        _mint(_to, _amount); //минтим токены
    }

    function burn(address _from, uint256 _amount) public {
        if(_amount == type(uint256).max){ // если передано максимальное значение, сжигаем весь баланс
            _amount = balanceOf(_from); // получаем текущий баланс с учетом процентов
        }
        _mintAccuredInterest(_from);// начисляем проценты перед сжиганием
        _burn(_from, _amount);// сжигаем токены
    }



    // Тут мы возвращаем процентную ставку пользователя
    function getUserInterestRate(address user) public view returns (uint256) {
        return s_userInterestRate[user]; 
    }
    /**  
     * @dev Internal function to mint accrued interest to a user.
     * This function calculates the interest accrued since the last update,
     * mints the corresponding amount of tokens, and updates the user's last updated timestamp.
     * @param _user The address of the user to mint interest for.
*/
    function _mintAccuredInterest(address _user) internal {
        uint256 privesionPrinciplBalance = super.balanceOf(_user); //тут мы получаем баланс без учета процентов
        uint256 currentBalance= balanceOf(_user); //тут мы получаем баланс с учетом процентов
        uint256 balanceIncrease = currentBalance - privesionPrinciplBalance; //тут мы считаем разницу

        s_userLastUpdatedTimestamp[_user] = block.timestamp; //обновляем таймстамп
        _mint(_user, balanceIncrease); //минтим разницу
    }

}
