//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../EscrowP2P.sol";

contract ESCROW_FACTORY {
    uint256 contractId;
    ///@notice get address by the contract's id
    mapping(uint256 => address) public contracts;

    event ContractCreated(address contr, address asset, address patyA, address partyB, uint256 id);

    function createContract(
        IERC20 asset,
        address partyA,
        address partyB,
        uint256 depTime,
        uint256 signTime
    ) external returns(address) {
        require(address(asset) != address(0), "ESCROW_FACTORY: `asset` == zero address");
        bytes memory bytecode = abi.encodePacked(
            type(EscrowP2P).creationCode,
            abi.encode(asset, partyA, partyB, depTime, signTime)
        );

        uint256 id = contractId;
        bytes32 salt = keccak256(abi.encodePacked(partyA, partyB, asset, id));
        address escrow;
        assembly {
            escrow := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        emit ContractCreated(escrow, address(asset), partyA, partyB, id);
        contracts[id] = escrow;
        contractId++;
        
        return escrow;
    }
}