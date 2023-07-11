// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SOON_PRESALE is Ownable {

    using SafeMath for uint256;

    uint8 pauseContract = 0;
   
    ERC20 soonToken;
    address soonAddress;
    uint256 soonDecimal;
    
    ERC20 purchaseToken;
    address purchaseAddress;
    uint256 purchaseDecimal;

    uint256 normalSwapRate;
    uint256 whitelistSwapRate;

    address managerWallet = 0x79CA15110241605AE97F73583F5C3f140506fb80;
    address[] devWalletList;

    mapping(address=>bool) whitelist;

    uint256 maxWhitelist;
    uint256 maxNormal;
    mapping(address=>uint256) purchasedAmount;

    event Received(address, uint);
    event Fallback(address, uint);
    event SetContractStatus(address addr, uint256 pauseValue);
    event ChangePresaledTokenAddress(address owner, address newAddr);
    event WithdrawAll(address addr, uint256 token, uint256 native);
    event ChangeRealTokenAddress(address owner, address newAddr);
    event Swapped(uint256 amountIn, uint256 amountOut);
    
    constructor(address _soonAddress, address _purchaseAddress, uint256 _normalSwapRate, uint256 _whitelistSwapRate) 
    {          
        soonAddress = _soonAddress;
        soonToken = ERC20(soonAddress);
        soonDecimal = soonToken.decimals();

        purchaseAddress = _purchaseAddress;
        purchaseToken = ERC20(purchaseAddress);
        purchaseDecimal = purchaseToken.decimals();

        normalSwapRate = _normalSwapRate;
        whitelistSwapRate = _whitelistSwapRate;
    }
    
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable { 
        emit Fallback(msg.sender, msg.value);
    }

    function getContractStatus() public view returns (uint8) {
        return pauseContract;
    }

    function setContractStatus(uint8 _newPauseContract) external onlyOwner {
        pauseContract = _newPauseContract;
        emit SetContractStatus(msg.sender, _newPauseContract);
    }

    function getSoonTokenAddress() public view returns(address){
        return soonAddress;
    }

    function setSoonTokenAddress(address _addr) external onlyOwner {
        require(pauseContract == 0, "Contract Paused");
        soonAddress = _addr;
        soonToken = ERC20(soonAddress);
        emit ChangeRealTokenAddress(msg.sender, soonAddress);
    }

    function getNormalSwapRate() external view returns(uint256){
        return normalSwapRate;
    }

    function setNormalSwapRate(uint256 _normalSwapRate) external onlyOwner{
        normalSwapRate = _normalSwapRate;
    }

    function getWhitelistSwapRate() external view returns(uint256){
        return whitelistSwapRate;
    }

    function setWhitelistSwapRate(uint256 _whitelistSwapRate) external onlyOwner{
        whitelistSwapRate = _whitelistSwapRate;
    }

    function getManagerWallet() external view returns(address){
        return managerWallet;
    }

    function setManagerWallet(address _newWallet) external onlyOwner{
        managerWallet = _newWallet;
    }

    function getDevWalletList() external  view returns( address[] memory){
        return devWalletList;
    }

    function addDevWallet(address _newDev) external onlyOwner{

        require(devWalletList.length <= 10, "Excceed amount");
        devWalletList.push(_newDev);
    }

    function getMaxWhitelist() external view returns(uint256){
        return maxWhitelist;
    }

    function setMaxWhitelist(uint256 _maxWhitelist) external onlyOwner{
        maxWhitelist = _maxWhitelist;
    }

    function getMaxNormal() external view returns(uint256){
        return maxNormal;
    }

    function setMaxNormal(uint256 _maxNormal) external onlyOwner{
        maxNormal = _maxNormal;
    }

    function removeDevWallet(address _oldDev) external onlyOwner{
        uint256 idx;

        for(idx=0; idx<devWalletList.length; idx++){
            if(devWalletList[idx] == _oldDev)
                break;
        }

        if(idx < devWalletList.length){
            devWalletList[idx] = devWalletList[devWalletList.length];
            devWalletList.pop();
        }
    }

    function swap(uint256 purchaseAmount) public payable{        
        require(pauseContract == 0, "Contract Paused");
        
        uint256 amountOut;
        
        if( whitelist[msg.sender] == true) 
        {
            amountOut = purchaseAmount * whitelistSwapRate * purchaseDecimal / soonDecimal;
            purchasedAmount[msg.sender] += amountOut;

            require(purchasedAmount[msg.sender] <= maxWhitelist, "Exceed purchased amount");
        }    
        else {
            amountOut = purchaseAmount * normalSwapRate * purchaseDecimal / soonDecimal;
            purchasedAmount[msg.sender] += amountOut;

            require(purchasedAmount[msg.sender] <= maxNormal, "Exceed purchased amount");
        }            

        require(soonToken.balanceOf(address(this)).sub(amountOut) >= 0 , "Sorry, insufficient soon tokens.");
        
        soonToken.transfer(msg.sender, amountOut);

        uint256 idx;

        for(idx = 0; idx < devWalletList.length; idx++){
            uint256 amountToDev = purchaseAmount / 52;
            purchaseToken.transfer(devWalletList[idx], amountToDev);
        }

        purchaseToken.transfer(managerWallet, purchaseAmount - (purchaseAmount / 52) * 10);

        emit Swapped(msg.value, amountOut);
    }

    function getAmountOut(uint256 _amountIn) public view returns(uint256) {    
        require(_amountIn > 0 , "Invalid amount.");

        uint256 amountOut ;

        if( whitelist[msg.sender] == true) 
        {
            amountOut = _amountIn * whitelistSwapRate * purchaseDecimal / soonDecimal;
        }    
        else {
            amountOut = _amountIn * normalSwapRate * purchaseDecimal / soonDecimal;
        }            

        return amountOut;
    }

    function withdrawAll(address _addr) external onlyOwner{
        uint256 balance = ERC20(_addr).balanceOf(address(this));
        if(balance > 0) {
            ERC20(_addr).transfer(msg.sender, balance);
        }
        address payable mine = payable(msg.sender);
        if(address(this).balance > 0) {
            mine.transfer(address(this).balance);
        }
        emit WithdrawAll(msg.sender, balance, address(this).balance);
    }
}

