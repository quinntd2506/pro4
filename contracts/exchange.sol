// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "hardhat/console.sol";

contract TokenExchange is Ownable {
    string public exchange_name = "FunTx";

    // paste token contract address here
    // e.g. tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3
    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // TODO: paste token contract address here
    Token public token = Token(tokenAddr);

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    // Fee Pools
    uint private token_fee_reserves = 0;
    uint private eth_fee_reserves = 0;

    // Liquidity pool shares
    mapping(address => uint) private lps;

    // For Extra Credit only: to loop through the keys of the lps mapping
    address[] private lp_providers;

    // Total Pool Shares
    uint private total_shares = 0;

    // liquidity rewards
    uint private swap_fee_numerator = 3;
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    uint private multiplier = 10 ** 5;

    constructor() {}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens) external payable onlyOwner {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;



        // Pool shares set to a large value to minimize round-off errors
        total_shares = 10**5;
        // Pool creator has some low amount of shares to allow autograder to run
        lps[msg.sender] = 100;
    }

    // For use for ExtraCredit ONLY
    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(
            index < lp_providers.length,
            "specified index is larger than the number of lps"
        );
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // Function getReserves
    function getReserves() public view returns (uint, uint) {
        return (eth_reserves, token_reserves);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    /* ========================= Liquidity Provider Functions =========================  */

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint min_exchange_rate, uint max_exchange_rate) external payable {
        /*******: Implement this function *******/
        require(eth_reserves > 0 && token_reserves > 0, "Pool not created yet");
        require(msg.value > 0, "Must provide ETH");

        uint eth_added = msg.value;

        // uint currentRate = (token_reserves * multiplier) / eth_reserves; // debug
        // uint newRate = (token_reserves * multiplier) /
        //     (eth_reserves + eth_added);
        // require(
        //     newRate >= min_exchange_rate && newRate <= max_exchange_rate,
        //     "Slippage: rate out of bounds"
        // );

        require(_checkRateWithinSlippage(min_exchange_rate, max_exchange_rate), "Slippage: rate out of bounds");

        uint token_required = (eth_added * token_reserves) / eth_reserves;
        require(
            token.balanceOf(msg.sender) >= token_required,
            "Insufficient tokens"
        );
        require(
            token.allowance(msg.sender, address(this)) >= token_required,
            "Approve tokens first"
        );

        require(
            token.transferFrom(msg.sender, address(this), token_required),
            "Token transfer failed"
        );

        uint share = (eth_added * total_shares) / eth_reserves;
        lps[msg.sender] += share;
        total_shares += share;

        eth_reserves += eth_added;
        token_reserves += token_required;
        k = token_reserves * eth_reserves;

        if (!_isLP(msg.sender)) lp_providers.push(msg.sender);
    }

    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(
        uint amountETH,
        uint min_exchange_rate,
        uint max_exchange_rate
    ) public payable {
        /******* Implement this function *******/
        require(amountETH > 0 && amountETH < eth_reserves, "Invalid amount");

        // uint currentRate = (token_reserves * multiplier) / eth_reserves;
        // uint newRate = ((token_reserves -
        //     ((amountETH * token_reserves) / eth_reserves)) * multiplier) /
        //     (eth_reserves - amountETH);
        // require(
        //     newRate >= min_exchange_rate && newRate <= max_exchange_rate,
        //     "Slippage: rate out of bounds"
        // );

        require(_checkRateWithinSlippage(min_exchange_rate, max_exchange_rate), "Slippage: rate out of bounds");

        // share_to_remove
        uint share = (amountETH * total_shares) / eth_reserves;
        require(lps[msg.sender] >= share, "Not enough LP shares");

        uint token_amount = (share * token_reserves) / total_shares;

        // Ensure we don't drain the pool completely
        require(eth_reserves - amountETH >= 1, "Cannot leave less than 1 ETH in the pool");
        require(token_reserves - token_amount >= 1, "Cannot leave less than 1 token in the pool");

        uint ethFees = (share * eth_fee_reserves) / total_shares;
        uint tokenFees = (share * token_fee_reserves) / total_shares;

        lps[msg.sender] -= share;
        total_shares -= share;

        eth_reserves -= amountETH;
        token_reserves -= token_amount;

        eth_fee_reserves -= ethFees;
        token_fee_reserves -= tokenFees;

        k = token_reserves * eth_reserves;

        payable(msg.sender).transfer(amountETH + ethFees);
        require(
            token.transfer(msg.sender, token_amount + tokenFees),
            "Token transfer failed"
        );

        // If LP has no more shares, remove from providers list
        if (lps[msg.sender] == 0) _removeLPProvider(msg.sender);
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint min_exchange_rate, uint max_exchange_rate) external payable {
        /******* Implement this function *******/
        uint share = lps[msg.sender];
        require(share > 0, "No LP shares");

        uint amountETH = (share * eth_reserves) / total_shares;
        removeLiquidity(amountETH, min_exchange_rate, max_exchange_rate);
    }
    /***  Define additional functions for liquidity fees here as needed ***/

    /* ========================= Swap Functions =========================  */

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(
        uint amountTokens,
        uint max_exchange_rate
    ) external payable {
        /******* Implement this function *******/
        require(amountTokens > 0, "Must swap > 0 tokens");
        require(token_reserves > 0 && eth_reserves > 0, "Reserves cannot be 0");
        require(
            token.balanceOf(msg.sender) >= amountTokens,
            "Insufficient token balance"
        );
        require(
            token.allowance(msg.sender, address(this)) >= amountTokens,
            "Approve tokens first"
        );

        uint fee = (amountTokens * swap_fee_numerator) / swap_fee_denominator;
        uint input = amountTokens - fee;
        // Calculate ETH to return based on constant product formula (k = (x + Δx)(y - Δy))
        uint ethOut = (input * eth_reserves) / (token_reserves + input);
        require(
            ethOut > 0 && eth_reserves > ethOut + 1 ,
            "Insufficient liquidity"
        );

        uint rate = (ethOut * multiplier) / input;
        require(rate <= max_exchange_rate, "Slippage: ETH output too low");

        require(
            token.transferFrom(msg.sender, address(this), amountTokens),
            "Token transfer failed"
        );

        token_reserves += input;
        token_fee_reserves += fee;
        eth_reserves -= ethOut;
        k = token_reserves * eth_reserves;

        // Transfer ETH to sender
        payable(msg.sender).transfer(ethOut);
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate) external payable {
        /******* Implement this function *******/
        require(msg.value > 0, "Must send ETH");
        require(token_reserves > 0 && eth_reserves > 0, "Reserves cannot be 0");

        uint fee = (msg.value * swap_fee_numerator) / swap_fee_denominator;
        uint input = msg.value - fee;
        // Calculate tokens to return based on constant product formula (k = (x + Δx)(y - Δy))
        uint tokenOut = (input * token_reserves) / (eth_reserves + input);
        require(
            tokenOut > 0 && token_reserves > tokenOut + 1,
            "Insufficient token liquidity"
        );

        uint rate = (tokenOut * multiplier) / input;
        require(rate <= max_exchange_rate, "Slippage: token output too low");

        eth_reserves += input;
        eth_fee_reserves += fee;
        token_reserves -= tokenOut;
        k = token_reserves * eth_reserves;

        require(token.transfer(msg.sender, tokenOut), "Token transfer failed");
    }

    // --------------------- Helper Functions ---------------------

    function _isLP(address lp) private view returns (bool) {
        for (uint i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] == lp) return true;
        }
        return false;
    }

    function _removeLPProvider(address lp) private {
        for (uint i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] == lp) {
                removeLP(i);
                break;
            }
        }
    }

    // Calculate current exchange rate (ETH to token)
    function _calculateExchangeRate() private view returns (uint) {
        return (eth_reserves * multiplier) / token_reserves; 
    }

    // Check if exchange rate is within allowed slippage
    function _checkRateWithinSlippage(uint min_exchange_rate, uint max_exchange_rate) private view returns (bool) {
        uint current_rate = _calculateExchangeRate();
        return (current_rate >= min_exchange_rate && current_rate <= max_exchange_rate);
    }
}
