// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./CouponVerifier.sol";
import "./Interfaces/IDroplinkedBase.sol";

struct Coupon {
    bool isPercentage;
    uint value;
    uint secretHash;
    address couponProducer;
}

contract CouponManager is CouponVerifier{
    mapping (uint => bool) public couponAvailable;
    mapping (uint => Coupon) public coupons;

    event CouponAdded(uint secretHash, bool isPercentage, uint value, address couponProducer);
    event CouponRemoved(uint secretHash, address couponProducer);

    function addCoupon(uint _secretHash, bool _isPercentage, uint _value) external {
        require(!couponAvailable[_secretHash], "Coupon hash already exists");
        couponAvailable[_secretHash] = true;
        
        Coupon memory cp;
        cp.isPercentage = _isPercentage;
        cp.secretHash = _secretHash;
        cp.value = _value;
        cp.couponProducer = msg.sender;
        coupons[_secretHash] = cp;
        
        emit CouponAdded(_secretHash, _isPercentage, _value, msg.sender);
    }

    function removeCoupon(uint secretHash) external {
        require(couponAvailable[secretHash], "Coupon hash does not exist");
        require(coupons[secretHash].couponProducer == msg.sender, "Only producer can remove a coupon");
        
        delete coupons[secretHash];
        couponAvailable[secretHash] = false;
        
        emit CouponRemoved(secretHash, msg.sender);
    }

    function combineUint128(uint128 a1, uint128 a2) internal pure returns (uint) {
        uint b = uint(a1) << 128;
        b += a2;
        return b;
    }

    function checkAndGetCoupon(CouponProof calldata _proof) external view returns(Coupon memory) {
        uint a1 = _proof._pubSignals[0];
        uint a2 = _proof._pubSignals[1];
        uint _hash = combineUint128(uint128(a1), uint128(a2));
    
        require(couponAvailable[_hash], "The coupon hash is not available");
        require(uint(uint160(msg.sender)) == _proof._pubSignals[2], "No front running!");
        require(verifyProof(_proof._pA, _proof._pB, _proof._pC, _proof._pubSignals), "Proof is invalid");
    
        return coupons[_hash];
    }
}