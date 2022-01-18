//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./Escrow.sol";

contract EscrowFactory {
    uint256 private contractId;

    mapping(uint256 => Escrow) public contractIds;

    function createEscrow(address _tokenAddr, address payable _userETH, address payable _userERC20) external returns(address) {
        Escrow escrow = new Escrow(_tokenAddr, _userETH, _userERC20);
        contractId++;
        contractIds[contractId] = escrow;
        return address(contractIds[contractId]);
    }
}