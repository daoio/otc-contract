//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/** 
*   @title OTC
*   @notice smart-cotnract for ERC20->ETH OTC deals
*
*   ///////////////////////////////////////////////////////////////////////////////
*   ///////////////////////     CONDITIONS OF THE DEAL     ///////////////////////
*   /////////////////////////////////////////////////////////////////////////////
*
*   1. There is two parties `A` and `B`
*   2. Assumed that `A` deposits pre-aggred (off-chain) quantity of ETH waiting to 
*   receive ERC20 token from `B`
*   3. `B` deposits quantity of needed ERC20 token, pre-agreed off-chain
*   4. If both deposits has been received by this contract then parties can sign it
*   5. if the parties or one of the parties, with the deposits made, decide to 
*   abandon the deal and the contract has not yet been signed by both of them, 
*   the parties of the deal can rescind contract taking initial deposits
*   6. if both amounts correspond to the pre-agreed amounts and the parties are 
*   satisfied with everything, they sign a contract. When the contract is signed by both, 
*   the funds can be withdrawn by them
*/
contract OTC is ReentrancyGuard {
    ///@notice ERC20 asset for exchange
    IERC20 private asset;

    /**
    *   @notice certain time when: 
    *   1. deposits are accepted
    *   2. signing can be done
    *   to properly close the deal
    *   @notice If time has been expired
    *   on any action then deposits returned
    *   and contract is destructed by call to
    *   function that corresponds to the expired action
    */
    struct Periods {
        uint256 depositTime; // depositTime - time in milliseconds when both parties can make deposits
        uint256 signingTime; // signingTime - time in milliseconds when both parties can sign the contract
    }
    Periods public periods;

    ///@notice track parties actions
    struct Party {
        address addr;
        bool deposited;
        bool signed;
        bool rescinded;
    }
    Party public partyA; // ETH -> ERC20
    Party public partyB; // ERC20 -> ETH

    mapping(address => Party) public parties;

    event Deposit(address indexed party, uint256 amount);
    event Withdraw(address indexed party, uint256 amount);
    event Sign(address indexed party);
    event Rescind(address indexed party, uint256 amount);

    constructor(
        IERC20 _asset,
        address _partyA,
        address _partyB,
        uint256 _depositTime,
        uint256 _signingTime
    ) 
    {
        _initContract(
            _asset,
            _partyA,
            _partyB,
            (block.timestamp + _depositTime),
            ((block.timestamp + _depositTime) + _signingTime)
        );
    }

    /**
    *   @notice any action that is changes the states
    *   of the parties is reviewed by a set of
    *   modifiers linked to each action
    *   @notice Allowed actions based on the party state:
    *   1. false, false, false - deposit
    *   2. true, false, false - sign, rescind
    *   3. true, true, false - withdraw
    *   4. true, true, true - deal has been successfully closed - contract destructed
    */
    modifier depositReview(address party) {
        require(
            parties[party].addr == party &&
            parties[party].deposited == false &&
            parties[party].signed == false &&
            parties[party].rescinded == false,
            "OTC{depositReview}: Deposit condtions hasn't been met"
        );
        ///@notice in case deposit time expired
        if (periods.depositTime < block.timestamp) {
            _returnDeposits();
        }
        _;
    }

    modifier signingReview() {
        require(
            (parties[msg.sender].addr == partyA.addr || parties[msg.sender].addr == partyB.addr) &&
            parties[msg.sender].deposited == true &&
            parties[msg.sender].signed == false &&
            parties[msg.sender].rescinded == false,
            "OTC{signingReview}: Signing condtions hasn't been met"
        );
        ///@notice in case signing time expired
        if (periods.signingTime < block.timestamp) {
            _returnDeposits();
        }
        _;
    }

    modifier rescindReview(address party) {
        require(
            parties[msg.sender].addr == party &&
            parties[msg.sender].deposited == true &&
            parties[msg.sender].signed == false &&
            parties[msg.sender].rescinded == false,
            "OTC{rescindReview}: Rescind condtions hasn't been met" 
        );
        _;
    }

    modifier exchangeReview(address party) {
        require(
            parties[msg.sender].addr == party &&
            parties[msg.sender].deposited == true &&
            parties[msg.sender].signed == true &&
            parties[msg.sender].rescinded == false,
            "OTC{rescindReview}: Withdraw condtions hasn't been met" 
        );
        _;
    }

    /*
        *************
        ** GETTERS **
        *************
    */
    ///@notice parties can check if needed amount of `asset` is on the contract's balance
    function getAssetbalance() external view returns(uint256) {
        return asset.balanceOf(address(this));
    }

    ///@notice parties can check if needed amount of ether is on the contract's balance
    function getEthBalance() external view returns(uint256) {
        return address(this).balance;
    }

    /*
        *************
        ** DEPOSIT **
        *************
    */
    ///@notice only `partyA` can deposit ETH
    function depositEth() external payable depositReview(partyA.addr) nonReentrant {
        ///@notice no need for deals with 0 amount pre-agreed
        require(msg.value > 0, "OTC{depositEth}: eth amount should be >0");
        _updatePartyState(msg.sender, true, false, false);

        emit Deposit(msg.sender, msg.value);
    }

    ///@notice only `partyB` can deposit ERC20
    function depositAsset(uint256 amount) external depositReview(partyB.addr) nonReentrant {
        require(amount > 0, "OTC{depositAsset}: `asset` amount should be >0");
        ///@notice approve `amount` first
        asset.transferFrom(msg.sender, address(this), amount);
        _updatePartyState(msg.sender, true, false, false);

        emit Deposit(msg.sender, amount);
    }

    /*
        *************
        ** SIGNING **
        *************
    */
    ///@notice accept that proper amount of funds has been sent by a counterparty
    ///@notice once contract is signed this action can't be canceled 
    function signContract() external signingReview nonReentrant {
        _updatePartyState(msg.sender, true, true, false);

        emit Sign(msg.sender);
    }

    /*
        **************
        ** EXCHANGE **
        **************
    */
    ///@notice withdrawal of `asset` allowed only to `A`
    function withdrawAsset() external exchangeReview(partyA.addr) {
        uint256 amount = asset.balanceOf(address(this));
        asset.transfer(msg.sender, amount);
        _updatePartyState(msg.sender, true, true, true);

        emit Withdraw(msg.sender, amount);

        if (
            partyB.deposited == true &&
            partyB.signed == true &&
            partyB.rescinded == true
        ) {
            selfdestruct(payable(address(0)));
        }
    }

    ///@notice withdrawal of ether allowed only to `B`
    function withdrawEther() external exchangeReview(partyB.addr) {
        uint256 amount = address(this).balance;

        /**
        *   @notice if `A` already withdraw his tokens
        *   then ether would be sent to `B` using `selfdestruct`
        */
        if (
            partyA.deposited == true &&
            partyA.signed == true &&
            partyA.rescinded == true
        ) {
            emit Withdraw(msg.sender, amount);
            selfdestruct(payable(msg.sender));
        } else {
            payable(msg.sender).transfer(amount);
            _updatePartyState(msg.sender, true, true, true);
            emit Withdraw(msg.sender, amount);
        }
    }

    /*
        **********************
        ** RESCIND CONTRACT **
        **********************
    */
    ///@notice rescind conrtact and return funds
    function rescindContractA() external rescindReview(partyA.addr) nonReentrant {
        _returnDeposits();
    }

    ///@notice rescind conrtact and return funds
    function rescindContractB() external rescindReview(partyB.addr) nonReentrant {
        _returnDeposits();
    }

    /*
        ***************
        ** INTERNALS **
        ***************
    */
    ///@notice set state variables to values defined in a constructor
    function _initContract(
        IERC20 _asset,
        address _partyA,
        address _partyB,
        uint256 _depositTime,
        uint256 _rescindTime
    ) internal {
        asset = _asset;
        partyA = Party(_partyA, false, false, false);
        partyB = Party(_partyB, false, false, false);
        parties[_partyA] = partyA;
        parties[_partyB] = partyB;
        periods = Periods(_depositTime, _rescindTime);
    }
    
    ///@notice use in deposits and signings
    function _updatePartyState(address _party, bool _deposited, bool _signed, bool _rescinded) internal {
        parties[_party].deposited = _deposited;
        parties[_party].signed = _signed; 
        parties[_party].rescinded = _rescinded;
    }

    ///@notice return deposits and destruct contract
    function _returnDeposits() internal {
        ///@notice balance can be 0 if deposit hasn't been made
        asset.transfer(partyB.addr, asset.balanceOf(address(this)));
        ///@notice selfdestruct contract and return ether to `A`
        selfdestruct(payable(partyA.addr));
    }
}
