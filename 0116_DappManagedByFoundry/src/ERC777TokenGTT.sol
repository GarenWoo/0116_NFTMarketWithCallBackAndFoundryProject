// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IRecipientContract {
    function tokensReceived(address, uint) external returns (bool);
}

contract ERC777TokenGTT is ERC20, ERC20Permit, ReentrancyGuard {
    using SafeERC20 for ERC777TokenGTT;
    using Address for address;
    address private owner;
    error NotOwner(address caller);
    error NoTokenReceived();
    error transferFail();
    event TokenMinted(uint amount, uint timestamp);

    constructor()
        ERC20("Garen Test Token", "GTT")
        ERC20Permit("Garen Test Token")
    {
        owner = msg.sender;
        /// @dev Initial totalsupply is 100,000
        _mint(msg.sender, 100000 * (10 ** uint256(decimals())));
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    function mint(address _recipient, uint _amount) external onlyOwner {
        _mint(_recipient, _amount);
        emit TokenMinted(_amount, block.timestamp);
    }

    function transferWithCallback(
        address _to,
        uint _amount
    ) external nonReentrant returns (bool) {
        bool transferSuccess = transfer(_to, _amount);
        if (!transferSuccess) {
            revert transferFail();
        }
        if (_isContract(_to)) {
            bool success = IRecipientContract(_to).tokensReceived(
                msg.sender,
                _amount
            );
            if (!success) {
                revert NoTokenReceived();
            }
        }
        return true;
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
