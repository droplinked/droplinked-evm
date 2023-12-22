// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./CouponVerifier.sol";
import "./structs.sol";

struct Coupon {
    bool isPercentage;
    uint value;
    uint secretHash;
    address couponProducer;
}

contract CouponManager is CouponVerifier{
    mapping (uint => Coupon) public coupons;

    event CouponAdded(uint secretHash, bool isPercentage, uint value, address couponProducer);
    event CouponRemoved(uint secretHash, address couponProducer);

    function couponAvailable(uint _secretHash) public view returns(bool) {
        return coupons[_secretHash].secretHash == _secretHash;
    }

    function addCoupon(uint _secretHash, bool _isPercentage, uint _value) external {
        require(!couponAvailable(_secretHash), "Coupon hash already exists");
        
        Coupon memory cp;
        cp.isPercentage = _isPercentage;
        cp.secretHash = _secretHash;
        cp.value = _value;
        cp.couponProducer = msg.sender;
        coupons[_secretHash] = cp;
        
        emit CouponAdded(_secretHash, _isPercentage, _value, msg.sender);
    }
    
    function removeCoupon(uint secretHash) external {
        require(couponAvailable(secretHash), "Coupon hash does not exist");
        require(coupons[secretHash].couponProducer == msg.sender, "Only producer can remove a coupon");
        delete coupons[secretHash];        
        emit CouponRemoved(secretHash, msg.sender);
    }

    function combineUint128(uint128 a1, uint128 a2) internal pure returns (uint) {
        return uint256(bytes32(abi.encodePacked(a1,a2)));
    }

    function checkAndGetCoupon(CouponProof calldata _proof) external view returns(Coupon memory) {
        uint a1 = _proof._pubSignals[0];
        uint a2 = _proof._pubSignals[1];
        uint _hash = combineUint128(uint128(a1), uint128(a2));
    
        require(couponAvailable(_hash), "The coupon hash is not available");
        require(uint(uint160(msg.sender)) == _proof._pubSignals[2], "No front running!");
        require(verifyProof(_proof._pA, _proof._pB, _proof._pC, _proof._pubSignals), "Proof is invalid");
    
        return coupons[_hash];
    }
}