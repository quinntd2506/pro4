// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Your token contract
contract Token is Ownable, ERC20 {
    string private constant _symbol = "LOLO"; // TODO: Give your token a symbol (all caps!)
    string private constant _name = "HAHATOKEN"; // TODO: Give your token a name

    bool private mintDisabled = false;

    // TODO: add private members as needed!
    // TODO: if you create private member, initialize it in the constructor

    constructor() ERC20(_name, _symbol) {}

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    // Function mint: Create more of your tokens.
    // You can change the inputs, or the scope of your function, as needed.
    // Do not remove the onlyOwner modifier!
    function mint(uint amount) public onlyOwner {
        require(!mintDisabled, "Minting has been disabled");
        _mint(msg.sender, amount);
    }

    // Function disable_mint: Disable future minting of your token.
    // You can change the inputs, or the scope of your function, as needed.
    // Do not remove the onlyOwner modifier!
    function disable_mint() public onlyOwner {
        /**
         * @dev Disable minting forever. Only callable by the contract owner.
         * Once called, minting can never be enabled again.
         */
        mintDisabled = true;
    }
}
