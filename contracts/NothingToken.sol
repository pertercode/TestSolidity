// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract TestToken is ERC20, ERC20Permit {
    event ERC20AirdropToken(
        address indexed sender,
        uint256 address_count,
        uint256 values
    );

    event ERC20ClaimToken(
        address indexed sender,
        uint256 airdrop_id,
        uint256 value,
        address indexed to
    );

    event ERC20EthAirdropToken(
        address indexed sender,
        uint256 balance,
        uint256 address_count,
        uint256 values
    );

    event ERC20EthClaimToken(
        address indexed sender,
        uint256 airdrop_id,
        uint256 value,
        address indexed to
    );

    event ERC20PledgeToken(
        address indexed sender,
        uint256 value,
        address indexed to
    );

    event ERC20RedemptionToken(
        address indexed sender,
        uint256 value,
        address indexed to
    );

    error ERC20ClaimTokenVerifySign(
        address sender,
        uint256 airdrop_id,
        uint256 value,
        address to
    );

    error ERC20EthClaimTokenVerifySign(
        address sender,
        uint256 airdrop_id,
        uint256 value,
        address to
    );

    error ERC20EthTransferInsufficientBalance(
        address sender,
        uint256 balance,
        uint256 values,
        address to
    );

    error ERC20EthAirdropInsufficientBalance(
        address sender,
        uint256 balance,
        uint256 values
    );

    address private airdrop_addr;
    address private fluidity_addr;
    address private pledge_addr;

    mapping(uint256 => bool) private _airdrops;

    mapping(uint256 => bool) private _airdrops_eth;

    mapping(uint256 => bool) private _redemption;

    constructor(address airdrop, address fluidity ,address _pledge)
        ERC20("Test", "TET", 0)
        ERC20Permit("Test")
    {
        airdrop_addr = airdrop;
        fluidity_addr = fluidity;
        pledge_addr = _pledge;
    }

    function airdrop_token(
        address[] calldata address_all,
        uint256[] calldata values
    ) public returns (bool) {
        require(address_all.length > 0 && address_all.length == values.length);

        uint256 _total = 0;
        for (uint32 i = 0; i < address_all.length; i++) {
            transfer(address_all[i], values[i]);
            _total += values[i];
        }

        emit ERC20AirdropToken(msg.sender, address_all.length, _total);

        return true;
    }

    function claim_token(
        uint256 value,
        uint256 airdrop_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public returns (bool) {
        require(_airdrops[airdrop_id] == false);

        uint256 fromBalance = balanceOf(airdrop_addr);
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(airdrop_addr, fromBalance, value);
        }

        string memory _message = string.concat(
            "_",
            Strings.toHexString(msg.sender),
            "_",
            Strings.toString(airdrop_id),
            "_",
            Strings.toString(value)
        );
        string memory _message_len = Strings.toString(bytes(_message).length);
        string memory pack = string.concat(
            "\x19Ethereum Signed Message:\n",
            _message_len,
            _message
        );
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(pack));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);

        if (signer != airdrop_addr) {
            revert ERC20ClaimTokenVerifySign(
                airdrop_addr,
                airdrop_id,
                value,
                msg.sender
            );
        }

        _transfer(airdrop_addr,msg.sender, value);

        _airdrops[airdrop_id] = true;

        emit ERC20ClaimToken(airdrop_addr, airdrop_id, value, msg.sender);

        return true;
    }

    function balanceEth() public  view returns (uint256) {
        return address(this).balance;
    }

    function _transferEth(address to, uint256 amount) private {
        if (msg.sender == airdrop_addr) {
            require(amount != type(uint256).max);
            if (balanceEth() < amount) {
                revert ERC20EthTransferInsufficientBalance(
                    address(this),
                    balanceEth(),
                    amount,
                    to
                );
            }
            payable(to).transfer(amount);
        }
    }

    function airdrop_eth(
        address[] calldata address_all,
        uint256[] calldata values
    ) public returns (bool) {
        require(address_all.length > 0 && address_all.length == values.length);

        if (msg.sender == airdrop_addr) {
            uint256 totalValues = 0;
            for (uint32 i = 0; i < address_all.length; i++) {
                totalValues += values[i];
            }

            if (balanceEth() < totalValues) {
                revert ERC20EthAirdropInsufficientBalance(
                    address(this),
                    balanceEth(),
                    totalValues
                );
            }

            for (uint32 i = 0; i < address_all.length; i++) {
                _transferEth(address_all[i], values[i]);
            }

            emit ERC20EthAirdropToken(
                address(this),
                balanceEth(),
                address_all.length,
                totalValues
            );

            return true;
        }

        return false;
    }

    function claim_eth(
        uint256 value,
        uint256 airdrop_eth_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public returns (bool) {
        require(value != type(uint256).max);

        require(_airdrops_eth[airdrop_eth_id] == false);

        if (balanceEth() < value) {
            revert ERC20EthTransferInsufficientBalance(
                address(this),
                balanceEth(),
                value,
                msg.sender
            );
        }

        

        string memory _message = string.concat(
            "eth_",
            Strings.toHexString(msg.sender),
            "_",
            Strings.toString(airdrop_eth_id),
            "_",
            Strings.toString(value)
        );

        string memory _message_len = Strings.toString(bytes(_message).length);
        string memory pack = string.concat(
            "\x19Ethereum Signed Message:\n",
            _message_len,
            _message
        );
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(pack));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);

        if (signer != airdrop_addr) {
            revert ERC20EthClaimTokenVerifySign(
                address(this),
                airdrop_eth_id,
                value,
                msg.sender
            );
        }


        payable(msg.sender).transfer(value);

        _airdrops_eth[airdrop_eth_id] = true;

        emit ERC20EthClaimToken(
            address(this),
            airdrop_eth_id,
            value,
            msg.sender
        );

        return true;
    }


    function pledge(uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, pledge_addr, value);
        emit ERC20PledgeToken(msg.sender,value,pledge_addr);
        return true;
    }

    function redemption(
        uint256 value,
        uint256 redemption_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public returns (bool) {

        require(_redemption[redemption_id] == false);

        uint256 fromBalance = balanceOf(pledge_addr);
        
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(pledge_addr, fromBalance, value);
        }

        

        string memory _message = string.concat(
            "redemption_",
            Strings.toHexString(msg.sender),
            "_",
            Strings.toString(redemption_id),
            "_",
            Strings.toString(value)
        );

        string memory _message_len = Strings.toString(bytes(_message).length);
        string memory pack = string.concat(
            "\x19Ethereum Signed Message:\n",
            _message_len,
            _message
        );
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(pack));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);

        if (signer != pledge_addr) {
            return false;
        }

        _transfer(pledge_addr, msg.sender, value);

        _redemption[redemption_id] = true;

        emit ERC20RedemptionToken(pledge_addr, value, msg.sender);

        return true;
    }

    function withdrawEther(uint256 amount) public payable returns (bool) {
        if (msg.sender == airdrop_addr) {
            _transferEth(airdrop_addr, amount);
            return true;
        }
        return false;
    }


    fallback() external payable {}

    receive() external payable {}
}
