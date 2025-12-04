//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author ZeroWeb3
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each will user will have their own interest rate that is the global interest rate at the time of depositing.
 */

contract RebaseToken is ERC20, Ownable, AccessControl {
    /////////////////////
    // State Variables
    /////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 currentInterestRate, uint256 newInterestRate);

    /////////////////////
    // State Variables
    /////////////////////
    bytes32 private constant MINTER_BURN_ROLE = keccak256("MINTER_BURN_ROLE"); // роль минтера
    uint256 private s_interestRate = 5e10; //(5*PRESISION_FACTOR)/1e8;
    mapping(address => uint256) public s_userInterestRate; // хранит процентную ставку пользователя
    mapping(address => uint256) public s_userLastUpdatedTimestamp; // хранит последний таймстамп обновления пользователя
    uint256 private constant PRESISION_FACTOR = 1e18; // precision factor for interest calculations

    /////////////////////
    // Events
    /////////////////////
    event InterestRateUpdated(uint256 newInterestRate); // событие обновления процентной ставки

    /////////////////////
    // Constructor
    /////////////////////

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {} //инициализируем ERC20 токен с именем и символом

    /////////////////////
    // Functions
    /////////////////////

    /**
     * @dev Grants the MINTER_BURN_ROLE to a specified address.
     * Can only be called by the contract owner.
     * @param _minterBurner The address to be granted the MINTER_BURN_ROLE.
     */
    function grandMinterBurnRole(address _minterBurner) public onlyOwner {
        _grantRole(MINTER_BURN_ROLE, _minterBurner);
    }

    // Тут мы переопределяем баланс пользователя с учетом накопленных процентов
    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * _calculateUserAcumulatedInterestLastUpdate(_user) / PRESISION_FACTOR;
    }

    /**
     * @dev Calculates the accumulated interest for a user since their last update.
     * @param _user The address of the user.
     * @return linearInterest The accumulated interest factor since the last update.
     *
     */
    function _calculateUserAcumulatedInterestLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user]; // считаем время прошедшее с последнего обновления
        linearInterest = (PRESISION_FACTOR + (s_userInterestRate[_user] * timeElapsed)); // считаем линейный интерес
    }

    /**
     * @dev Returns the principal balance of a user without accrued interest.
     * @param _user The address of the user.
     * @return The principal balance of the user.
     */
    function principalBalanceOf(address _user) public view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @dev Sets a new global interest rate.
     * The new interest rate must be less than the current interest rate.
     * Emits an {InterestRateUpdated} event upon successful update.
     * @param _newRate The new interest rate to set.
     */
    function setInterestRate(uint256 _newRate) public onlyOwner {
        if (_newRate < s_interestRate) {
            // проверяем что новая ставка меньше текущей
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newRate); // выбрасываем ошибку если новая ставка больше текущей
        }
        s_interestRate = _newRate; // обновляем глобальную процентную ставку
        emit InterestRateUpdated(_newRate); // эмитируем событие
    }

    /**
     * @dev Mints a specified amount of tokens to a given address.
     * This function first mints any accrued interest for the user before minting the new tokens.
     * It also updates the user's interest rate to the current global interest rate.
     * @param _to The address to which the tokens will be minted.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) public onlyRole(MINTER_BURN_ROLE) {
        _mintAccuredInterest(_to); //начисляем проценты перед минтом
        s_userInterestRate[_to] = s_interestRate; //обновляем процентную ставку пользователя
        _mint(_to, _amount); //минтим токены
    }

    /**
     * @dev Burns a specified amount of tokens from a given address.
     * This function first mints any accrued interest for the user before burning the tokens.
     * If the burn amount is set to the maximum uint256 value, it burns the entire balance of the user.
     * @param _from The address from which to burn tokens.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) public onlyRole(MINTER_BURN_ROLE) {
        // if (_amount == type(uint256).max) {
        //     // если передано максимальное значение, сжигаем весь баланс
        //     _amount = balanceOf(_from); // получаем текущий баланс с учетом процентов
        // }
        _mintAccuredInterest(_from); // начисляем проценты перед сжиганием
        _burn(_from, _amount); // сжигаем токены
    }

    /**
     * @dev Overridden transfer function to include interest accrual for both sender and recipient.
     * This function mints accrued interest for both the sender and recipient before executing the transfer.
     * If the transfer amount is set to the maximum uint256 value, it transfers the entire balance of the sender.
     * If the recipient has a zero balance, their interest rate is set to that of the sender.
     * @param _recipient The address of the recipient.
     * @param _amount The amount to transfer.
     * @return A boolean indicating whether the operation was successful.
     *
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(msg.sender); //начисляем проценты отправителю
        _mintAccuredInterest(_recipient); //начисляем проценты получателю
        if (_amount == type(uint256).max) {
            // если передано максимальное значение, отправляем весь баланс
            _amount = balanceOf(msg.sender); // получаем текущий баланс с учетом процентов
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender]; //если у получателя нулевой баланс, то устанавливаем ему процентную ставку отправителя
        }
        return super.transfer(_recipient, _amount); //вызываем стандартный трансфер
    }

    /**
     * @dev Overridden transferFrom function to include interest accrual for both sender and recipient.
     * This function mints accrued interest for both the sender and recipient before executing the transfer.
     * If the transfer amount is set to the maximum uint256 value, it transfers the entire balance of the sender.
     * If the recipient has a zero balance, their interest rate is set to that of the sender.
     * @param sender The address of the sender.
     * @param recipient The address of the recipient.
     * @param _amount The amount to transfer.
     * @return A boolean indicating whether the operation was successful.
     *
     */

    function transferFrom(address sender, address recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(sender); //начисляем проценты отправителю
        _mintAccuredInterest(recipient); //начисляем проценты получателю
        if (_amount == type(uint256).max) {
            // если передано максимальное значение, отправляем весь баланс
            _amount = balanceOf(sender); // получаем текущий баланс с учетом процентов
        }
        if (balanceOf(recipient) == 0) {
            s_userInterestRate[recipient] = s_userInterestRate[sender]; //если у получателя нулевой баланс, то устанавливаем ему процентную ставку отправителя
        }
        return super.transferFrom(sender, recipient, _amount); //вызываем стандартный трансфер
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
        uint256 currentBalance = balanceOf(_user); //тут мы получаем баланс с учетом процентов
        uint256 balanceIncrease = currentBalance - privesionPrinciplBalance; //тут мы считаем разницу

        s_userLastUpdatedTimestamp[_user] = block.timestamp; //обновляем таймстамп
        _mint(_user, balanceIncrease); //минтим разницу
    }
}
