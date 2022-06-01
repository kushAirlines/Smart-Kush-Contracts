// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleVesting is Ownable {
    using SafeERC20 for IERC20;

    event TokensVestingRevoked(address receiver, uint256 amount);

    address private _beneficiary;
    
    
    uint256 private _start;
    uint256 private _finish;
    uint256 private _duration;
    uint256 private _releasesCount;
    uint256 private _released;
    uint256 private _totalAmount;

    
    bool private _revocable;
    bool private _revoked;

    IERC20 private _token;

    constructor (address token, address beneficiary, uint256 totalAmount, uint256 start, uint256 duration, uint256 releasesCount,bool revocable )  {
        require(beneficiary != address(0), "TokensVesting: beneficiary is the zero address!");
        require(token != address(0), "TokensVesting: token is the zero address!");
        require(duration > 0, "TokensVesting: duration is 0!");
        require(releasesCount > 0, "TokensVesting: releases count is 0!");

        _token = IERC20(token);
        _beneficiary = beneficiary;
        _revocable = revocable;
        _duration = duration;
        _releasesCount = releasesCount;
        _start = start;
        _finish = _start + (_releasesCount * _duration);
        _totalAmount = totalAmount;

            
    }

    function getAvailableTokens() public view returns(uint256) {
        return _releasableAmount();
    }

   

    function claim() public {
        require(msg.sender == _beneficiary,"You are not authorized!");
        uint256 unreleased = _releasableAmount();
        require(unreleased > 0, "release: No tokens 4u!");

        _released =  _released + unreleased ;
        _token.safeTransfer(msg.sender, unreleased);

        

    }


    function revoke(address receiver) public onlyOwner {
        
        require(_revocable,"revoke: U cannot revoke!");
        require(!_revoked,"revoke: Token already revoked!");

        uint256 balance = _token.balanceOf(address(this));
        uint256 unreleased = _releasableAmount();
        uint256 refund = balance - unreleased;

        _revoked = true;
        _token.safeTransfer(receiver,refund);

        emit TokensVestingRevoked(receiver,refund);
        

    }


    function _releasableAmount() private view returns(uint256) {
        return (_vestedAmount() - _released); 
    }

    function _vestedAmount() private view returns(uint256) {
        

        if(block.timestamp < _start) {
            return 0;
        } else if (block.timestamp >= _finish  || _revoked) {
            return _totalAmount;
        } else {
            uint256 timeLeftAfterStart = block.timestamp - _start;
            uint256 availableReleases = timeLeftAfterStart / _duration;
            uint256 tokensPerRelease = _totalAmount / _releasesCount;

            return availableReleases * tokensPerRelease ;
        }

    }

}
