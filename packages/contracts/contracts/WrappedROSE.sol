// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {BridgeRemoteEndpointAPI} from "./IBridgeInterface.sol";

contract WrappedROSE is ERC20, ERC20FlashMint, ERC20Burnable, Ownable
{
    constructor()
        ERC20("Wrapped ROSE", "wROSE")
        Ownable(msg.sender)
    { }

    function mint(address in_holder, uint in_amount)
        external onlyOwner
    {
        _mint(in_holder, in_amount);
    }

    function _onBurn(uint in_amount, address in_receiver)
        internal
    {
        if( in_amount > 0 ) {
            BridgeRemoteEndpointAPI(owner()).burn(in_receiver, in_amount);
        }
    }

    function burn(uint in_amount)
        public override
    {
        _onBurn(in_amount, _msgSender());
        _burn(_msgSender(), in_amount);
    }

    function burn(uint in_amount, address in_receiver)
        public
    {
        _onBurn(in_amount, in_receiver);
        _burn(_msgSender(), in_amount);
    }

    function burnFrom(address account, uint256 value)
        public override
    {
        _onBurn(value, account);
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }

    function burnFrom(address account, uint256 value, address in_receiver)
        public
    {
        _onBurn(value, in_receiver);
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }

    function _update(address from, address to, uint256 value)
        internal override
    {
        // Ensure tokens can't be sent to the Host endpoint by accident
        require( from != owner() && to != owner() );
        super._update(from, to, value);
    }
}
