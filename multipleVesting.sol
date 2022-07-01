
pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SimpleVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event TokenVestingRevoked(address beneficiary, uint256 amount);
    event Released(address beneficiary, uint256 amount);

    address[] private _vestingSchedulesAddresses;
    mapping(address => VestingSchedule) private _vestingSchedules;
    uint256 private _totalVestingSchedulesAmount;


    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 releasedAmount;
        bool revoked;
    }


    uint256 private _start;
    uint256 private _finish;
    uint256 private _duration;
    uint256 private _releasesCount;

    
    bool private _revocable;


    IERC20 private _token;

    constructor (address token, uint256 start, uint256 duration, uint256 releasesCount,bool revocable )  {
        require(token != address(0), "TokensVesting: beneficiary is the zero address!");
        require(token != address(0), "TokensVesting: token is the zero address!");
        require(duration > 0, "TokensVesting: duration is 0!");
        require(releasesCount > 0, "TokensVesting: releases count is 0!");
        require(block.timestamp <= start,"Invalid timezone.");

        _token = IERC20(token);
        _revocable = revocable;
        _duration = duration;
        _releasesCount = releasesCount;
        _start = start;
        _finish = _start + (_releasesCount * _duration);
    }


    function getTokenAddress() external view returns(address) {
        return address(_token);
    }

   function getBeneficiarySchedule(address _beneficiary) public view returns(
       bool hasVesting,
       uint256 totalAmount,
       uint256 vestedAmount,
       uint256 releasedAmount,
       bool revoked
   ) { 
       VestingSchedule storage Schedule = _vestingSchedules[_beneficiary];
   return(
       (!Schedule.revoked && Schedule.beneficiary!=address(0)),
       Schedule.totalAmount,
       _vestedAmount(_beneficiary),
       Schedule.releasedAmount,
       Schedule.revoked
   );
   }


   function createVestingSchedules(VestingSchedule[] memory _vestingschedules) public onlyOwner {
       for(uint i = 0; i < _vestingschedules.length; i++) {
           createVestingSchedule(
               _vestingschedules[i].beneficiary,
               _vestingschedules[i].totalAmount
           );
       }
   }

   function createVestingSchedule(address _beneficiary, uint256 _totalAmount) private onlyOwner {
       require(_beneficiary != address(0),"Address 0 is detected.");
       require(_totalAmount > 0,"You cannot vest 0 amount");
       VestingSchedule storage Schedule = _vestingSchedules[_beneficiary];
       require(Schedule.totalAmount == 0,"You are already in game.");
       _vestingSchedules[_beneficiary] = VestingSchedule(
           _beneficiary,
           _totalAmount,
           0,
           false
       );
       _vestingSchedulesAddresses.push(_beneficiary);
       _totalVestingSchedulesAmount += _totalAmount;
   }


   function getVestingSchedule() external view returns(
       uint256 startTime,
       uint256 finishTime,
       uint256 interval,
       uint256 releasesCount,
       uint256 numberOfBeneficiaries,
       bool revocable
   )
   {
       return(
           _start, _finish, _duration, _releasesCount, 
           _vestingSchedulesAddresses.length, _revocable
       );
   }




    function claim() public nonReentrant  {
        VestingSchedule storage Schedule = _vestingSchedules[msg.sender];
        require(msg.sender == Schedule.beneficiary,"You are not authorized!");
        uint256 unreleased = _releasableAmount(msg.sender, Schedule.releasedAmount);
        require(unreleased > 0, "release: No tokens 4u!");

        uint256 balance = _token.balanceOf(address(this));
        require(balance >= unreleased,"Insufficient Balance.");

        Schedule.releasedAmount += unreleased;
        _totalVestingSchedulesAmount -= unreleased;
        _token.safeTransfer(payable(msg.sender), unreleased);

        emit Released(msg.sender, unreleased);     
    }


    function revoke(address _beneficiary, address receiver) external onlyOwner {
        
        require(_revocable,"revoke: U cannot revoke!");
        VestingSchedule storage Schedule = _vestingSchedules[_beneficiary];
        uint256 unreleased = _releasableAmount(_beneficiary, Schedule.releasedAmount);
        if(unreleased > 0 ) {
            _totalVestingSchedulesAmount -= unreleased;
            _token.safeTransfer(payable(receiver), unreleased);

        }
        Schedule.revoked = true;

        emit TokenVestingRevoked(_beneficiary, unreleased);
    }


    function _releasableAmount(address _beneficiary, uint256 _released) private view returns(uint256) {
        return (_vestedAmount(_beneficiary) - _released); 
    }

    function _vestedAmount(address _beneficiary) internal view returns(uint256) {
        VestingSchedule storage Schedule = _vestingSchedules[_beneficiary];

        if(block.timestamp < _start) {
            return 0;
        } else if (block.timestamp >= _finish  || Schedule.revoked) {
            return Schedule.totalAmount;
        } else {
            uint256 timeLeftAfterStart = block.timestamp - _start;
            uint256 availableReleases = timeLeftAfterStart / _duration;
            uint256 tokensPerRelease = Schedule.totalAmount / _releasesCount;

            return availableReleases * tokensPerRelease ;
        }

    }

}
