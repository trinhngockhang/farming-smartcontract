
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DD2Token is ERC20, Ownable {
    using SafeMath for uint256;

    /**
     * @dev A record status of minter.
     */
    mapping (address => bool) public minters;
    mapping (address => uint256) public mintingAllowance;
    
     /**
     * @dev maximum amount can be minted.
     */
    uint256 private immutable _cap;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);
    event MintingAllowanceUpdated(address indexed account, uint256 oldAllowance, uint256 newAllowance);

    constructor(uint256 cap_) public ERC20("DD2 Token", "DD2") {
        minters[msg.sender] = true;
        _cap = cap_;
    }
    
    function cap() public view returns(uint256) {
        return _cap;
    }

    function isMinter(address _account) public view returns(bool) {
        return minters[_account];
    }

    function burn(uint _amount) public onlyOwner {
        _burn(msg.sender, _amount);
    }

    function mint(address _to, uint256 _amount) public virtual {
        require(minters[msg.sender], "must have minter role to mint");
        require(mintingAllowance[msg.sender] >= _amount, "mint amount exceeds allowance");
        require(totalSupply().add(_amount) <= _cap, "mint amount exceeds cap");
        mintingAllowance[msg.sender] = mintingAllowance[msg.sender].sub(_amount);
        _mint(_to, _amount);
    }
    function addMinter(address _minter,uint256 _amount) public virtual onlyOwner {
        minters[_minter] = true;
        mintingAllowance[_minter] = _amount;
        emit MinterAdded(_minter);
    }
}
