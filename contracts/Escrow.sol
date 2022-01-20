//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Escrow {

    // ETH ---> ERC20 swap
    IERC20 private token;

    address payable userA; //sends eth ---> takes ERC20
    address payable userB; //sends ERC20 ---> takes ETH

    mapping(address => uint256) public signatures;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event FundsReturned(address indexed user, uint256 amount);

    /*
    Stages of the escrow contract execution,

    */
    enum Stages {
        noSignatures,
        oneSigned,
        twoSigned
    }

    Stages private stage = Stages.noSignatures;

    constructor(
        address _token, 
        address payable _ethSender, 
        address payable _tokenSender
        ) {
        token = IERC20(_token);
        userA = _ethSender;
        userB = _tokenSender;
    }

    modifier onlyA {
        require(msg.sender == userA);
        _;
    }

    modifier onlyB {
        require(msg.sender == userB);
        _;
    }

    function getContractStage() external view returns(Stages) {
        return stage;
    }


    // Deposit functions
    function depositEth() external payable onlyA {
        require(msg.sender == userA, "Only UserA can deposit ETH");
        signatures[msg.sender] = 1;
        emit Deposit(msg.sender, msg.value);
    }   

    function getEthContractBalance() external view returns(uint256) {
        return address(this).balance;
    }

    function depositERC20(uint256 _amount) external onlyB {
        address payable depositor = msg.sender;
        // UserB firstly should directly use approve(), to allow contract transfer funds from him
        token.transferFrom(depositor, address(this), _amount);
        signatures[msg.sender] = 1;
        emit Deposit(msg.sender, _amount);
    }

    function getERCbalance() external view returns(uint256) {
        return token.balanceOf(address(this));
    }


    // Signing
    function signContract() external {
        if (msg.sender == userA) {
            require(signatures[msg.sender] == 1);
            signatures[msg.sender] = 0;
                if (stage == Stages.noSignatures){
                    stage = Stages.oneSigned;
                } else if (stage == Stages.oneSigned) {
                    stage = Stages.twoSigned;
                }
        } else if (msg.sender == userB) {
            require(signatures[msg.sender] == 1);
            signatures[msg.sender] = 0;
                if (stage == Stages.noSignatures){
                    stage = Stages.oneSigned;
                } else if (stage == Stages.oneSigned) {
                    stage = Stages.twoSigned;
                }
        }
    }
    

    // If swap goes wrong
    function returnETH() external onlyA {
        require(stage != Stages.twoSigned);
        uint256 amount = address(this).balance;
        userA.transfer(address(this).balance);
        emit FundsReturned(msg.sender, amount);
    }

    function returnERC20() external onlyB {
        require(stage != Stages.twoSigned);
        uint256 amount = token.balanceOf(address(this));
        token.transfer(msg.sender, amount);
        emit FundsReturned(msg.sender, amount);
    }

    // Withdrawals
    function withdrawETH() external onlyB {
        require(stage == Stages.twoSigned);
        uint256 amount = address(this).balance;
        userA.transfer(address(this).balance);
        emit Withdraw(msg.sender, amount);
    }

    function withdrawERC20() external onlyA {
        require(stage == Stages.twoSigned);
        uint256 amount = token.balanceOf(address(this));
        token.transfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }
}
