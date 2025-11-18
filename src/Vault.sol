// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";



contract Vault {
    /////////////////////
    // State Variables
    /////////////////////
    error Vault__ReddemFailed();



    event Deposit(address indexed user, uint256 amount); // событие депозита
    event Redeem(address indexed user, uint256 amount); // событие редема


    IRebaseToken private immutable i_rebaseToken; // адрес рефбейс токена


    /////////////////////
    // Constructor
    /////////////////////
    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
}

    /////////////////////
    // Functions
    /////////////////////
    receive() external payable {}

    function deposit () external payable {
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }
    function redeem(uint256 _amount ) external {
        i_rebaseToken.burn(msg.sender,_amount);
        (bool succes, )=payable(msg.sender).call{value:_amount}("");
        if(!succes){
            revert Vault__ReddemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }




    /**
    * @dev Returns the address of the RebaseToken contract.
    * @return The address of the RebaseToken contract.
     */
    function getRebaseTokenAddress() public view returns (address) {
        return address(i_rebaseToken);
    }



}


