# 练习题 1（01.16）

## 改写 01.15 NFTMarket 合约，向其中加入 tokenReceived 方法：当用户向 NFTMarket 转入 token 时，自动购买 NFT

### NFTMarket 合约代码：

```solidity
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarket is IERC721Receiver {
    mapping(address => mapping(uint => uint)) private price;
    mapping(address => uint) private balance;
    address public immutable tokenAddr;
    mapping(address => mapping(uint => bool)) public onSale;
    error ZeroPrice();
    error NotOwner();
    error BidLessThanPrice(uint bidAmount, uint priceAmount);
    error NotOnSale();
    error withdrawalExceedBalance(uint withdrawAmount, uint balanceAmount);

    // This NFTMarket supports multiple ERC721 token，there's no need to fix the address of 'ERC721token Contract'，
    // Fix the address of ERC20token contract instead.
    constructor(address _tokenAddr) {
        tokenAddr = _tokenAddr;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function tokensReceived(
        address _nftAddr,
        uint _tokenId,
        uint _bid
    ) external {
        _buyNFT(_nftAddr, _tokenId, _bid);
    }

    // Before calling this function, need to approve this contract as an operator of the corresponding tokenId!
    function list(address _nftAddr, uint _tokenId, uint _price) external {
        if (msg.sender != IERC721(_nftAddr).ownerOf(_tokenId))
            revert NotOwner();
        if (_price == 0) revert ZeroPrice();
        require(
            onSale[_nftAddr][_tokenId] == false,
            "This NFT is already listed"
        );
        IERC721(_nftAddr).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            "List successfully"
        );
        IERC721(_nftAddr).approve(msg.sender, _tokenId);
        price[_nftAddr][_tokenId] = _price;
        onSale[_nftAddr][_tokenId] = true;
    }

    function delist(address _nftAddr, uint256 _tokenId) external {
        // The original owner, is the owner of the NFT when it was not listed.
        require(
            IERC721(_nftAddr).getApproved(_tokenId) == msg.sender,
            "Not original owner or Not on sale"
        );
        if (onSale[_nftAddr][_tokenId] != true) revert NotOnSale();
        IERC721(_nftAddr).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            "Delist successfully"
        );
        delete price[_nftAddr][_tokenId];
        onSale[_nftAddr][_tokenId] = false;
    }

    // Before calling this function, need to approve this contract with enough allowance!
    function buy(address _nftAddr, uint _tokenId, uint _bid) external {
        _buyNFT(_nftAddr, _tokenId, _bid);
    }

    function withdrawBalance(uint _value) external {
        if (_value > balance[msg.sender])
            revert withdrawalExceedBalance(_value, balance[msg.sender]);
        bool _success = IERC20(tokenAddr).transfer(msg.sender, _value);
        require(_success, "withdrawal failed");
        balance[msg.sender] -= _value;
    }

    function _buyNFT(address _nftAddr, uint _tokenId, uint _bid) internal {
        if (onSale[_nftAddr][_tokenId] != true) revert NotOnSale();
        if (_bid < price[_nftAddr][_tokenId])
            revert BidLessThanPrice(_bid, price[_nftAddr][_tokenId]);
        require(
            msg.sender != IERC721(_nftAddr).getApproved(_tokenId),
            "Owner cannot buy!"
        );
        bool _success = IERC20(tokenAddr).transferFrom(
            msg.sender,
            address(this),
            _bid
        );
        require(_success, "Fail to buy or Allowance is insufficient");
        balance[IERC721(_nftAddr).getApproved(_tokenId)] += _bid;
        IERC721(_nftAddr).transferFrom(address(this), msg.sender, _tokenId);
        delete price[_nftAddr][_tokenId];
        onSale[_nftAddr][_tokenId] = false;
    }

    function getPrice(
        address _nftAddr,
        uint _tokenId
    ) external view returns (uint) {
        return price[_nftAddr][_tokenId];
    }

    function getBalance() external view returns (uint) {
        return balance[msg.sender];
    }

    function getOwner(
        address _nftAddr,
        uint _tokenId
    ) external view returns (address) {
        return IERC721(_nftAddr).ownerOf(_tokenId);
    }
}
```

### ERC777 Token 合约代码：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ITokenBank {
    function tokensReceived(address, uint) external returns (bool);
}
interface INFTMarket {
    function tokensReceived(address, uint, uint) external returns (bool);
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
            bool success = ITokenBank(_to).tokensReceived(
                msg.sender,
                _amount
            );
            if (!success) {
                revert NoTokenReceived();
            }
        }
        return true;
    }

    function transferForNFTWithCallback(
        address _to,
        uint _tokenId,
        uint _bid
    ) external nonReentrant returns (bool) {
        bool transferSuccess = transfer(_to, _bid);
        if (!transferSuccess) {
            revert transferFail();
        }
        if (_isContract(_to)) {
            bool success = INFTMarket(_to).tokensReceived(
                msg.sender,
                _tokenId,
                _bid
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
```



## 合约部署、验证

**ERC777 Token 合约 URL**：
https://mumbai.polygonscan.com/address/0x7BdBE8630C134960D037033339A202f5e2Fb8f1E

**NFTMarket 合约 URL**：
https://mumbai.polygonscan.com/address/0x67e34b647b4fe15738ae5225B651D8a06A0ae229