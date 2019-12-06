pragma solidity ^0.5.0;

import "./zeppelin/token/ERC777/ERC777.sol";

interface ReversibleICO {
    function getReservedTokens(address) external view returns(uint256);
    function getUnlockedTokenAmount(address) external view returns(uint256);
    function getLockedTokenAmount(address) external view returns (uint256);
}

contract RicoToken is ERC777 {

    ReversibleICO public rICO;
    address public manager;
    bool public frozen; // default: false
    bool public initialized; // default: false

    constructor(
        uint256 _initialSupply,
        address[] memory _defaultOperators
    )
        ERC777("LYXeToken", "LYXe", _defaultOperators)
        public
    {
        _mint(msg.sender, msg.sender, _initialSupply, "", "");
        manager = msg.sender;
        frozen = true;
    }

    // since rico affects balances, changing the rico address
    // once setup should not be possible.
    function setup(address _rICO)
        public
        requireNotInitialized
        onlyManager
    {
        rICO = ReversibleICO(_rICO);
        frozen = false;
        initialized = true;
    }

    function changeManager(address _newManager) public onlyManager {
        manager = _newManager;
    }

    function setFrozen(bool _status) public onlyManager {
        frozen = _status;
    }

    /**
     * @dev Returns the amount of locked tokens owned by an account (`tokenHolder`).
     */
    function getLockedBalance(address tokenHolder) public view returns(uint) {
        return rICO.getLockedTokenAmount(tokenHolder);
    }

    /**
     * @dev Returns the amount of unlocked tokens owned by an account (`tokenHolder`).
     */
    function getUnlockedBalance(address tokenHolder) public view returns(uint) {
        return rICO.getUnlockedTokenAmount(tokenHolder);
        /*
        uint256 balance = _balances[tokenHolder];
        uint256 Locked = rICO.getLockedTokenAmount(tokenHolder);
        // uint256 reserved = rICO.getReservedTokens(tokenHolder);
        if(balance > 0 && Locked > 0 && balance >= Locked) {
            return balance.sub(Locked); // .sub(reserved);
        }
        return balance;
        */
    }

    /**
     * @dev Returns the amount of tokens owned by an account (`tokenHolder`).
     */
    function balanceOf(address tokenHolder) public view returns (uint256) {
        // if a user has contributed and is not whitelisted
        // their tokens have not been transferred to them yet
        // balance is stored in the rICO.participantsByAddress[tokenHolder].reservedTokens

        // a) once the whitelisting happens, and the tokens are transferred,
        // reservedTokens is zeroed and the value is added to boughtTokens

        // b) if user cancels using ETH, reservedTokens is zeroed

        // add the amount to our local balance
        return _balances[tokenHolder].add(rICO.getReservedTokens(tokenHolder));
    }

    /**
     * @dev Override ERC777 _burn - so users can't burn locked amounts
     */
    function _burn(
        address _operator,
        address _from,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
        internal
        requireInitialized
        requireNotFrozen
    {
        require(_amount <= _balances[_from].sub(rICO.getLockedTokenAmount(_from)), "getUnlockedBalance: Insufficient funds");
        ERC777._burn(_operator, _from, _amount, _data, _operatorData);
    }

    /**
     * @dev Override ERC777 _move
     *
     * 1 - users can send their full balance to rICO
     * 2 - for other receivers transfers are capped at unlocked balance
     */
    function _move(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _userData,
        bytes memory _operatorData
    )
        internal
        requireInitialized
        requireNotFrozen
    {
        if(_to == address(rICO)) {
            // full local balance that can be sent back to rico
            require(_amount <= _balances[_from], "Move: Insufficient funds");
        } else {
            // for every other receiving address limit the _amount to unlocked balance
            require(_amount <= _balances[_from].sub(rICO.getLockedTokenAmount(_from)), "getUnlockedBalance: Insufficient funds");
        }
        ERC777._move(_operator, _from, _to, _amount, _userData, _operatorData);
    }

    modifier onlyManager() {
        require(msg.sender == manager, "onlyManager: Only manager can call this method");
        _;
    }

    modifier requireInitialized() {
        require(initialized == true, "Contract must be initialized.");
        _;
    }
    modifier requireNotInitialized() {
        require(initialized == false, "Contract is already initialized.");
        _;
    }

    modifier requireNotFrozen() {
        require(frozen == false, "requireNotFrozen: Contract must not be frozen");
        _;
    }

}
