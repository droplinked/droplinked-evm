// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./CouponVerifier.sol";

contract CouponManager is CouponVerifer{
    struct Coupon{
        bool isPercentage; // if true: percentage mode, else: value mode
        uint value; // value: 100x
        uint secretHash; // The hash of the coupon secret
        address couponProducer; // The producer address who generated this coupon
    }
    mapping (uint => bool) public couponAvailable;
    mapping (uint => Coupon) public coupons;

    function addCoupon(uint secretHash, bool isPercentage, uint value) public{
        require(!couponAvailable[secretHash], "Coupon hash already exists");
        couponAvailable[secretHash] = true;
        Coupon memory cp;
        cp.isPercentage = isPercentage;
        cp.secretHash = secretHash;
        cp.value = value;
        cp.couponProducer = msg.sender;
        coupons[secretHash] = cp;
    }

    function removeCoupon(uint secretHash) public{
        require(couponAvailable[secretHash], "Coupon hash does not exist");
        require(coupons[secretHash].couponProducer == msg.sender, "Only producer can remove a coupon");
        delete coupons[secretHash];
        couponAvailable[secretHash] = false;
    }

    function constructHash(uint128 a1, uint128 a2) private pure returns(uint){
        uint b =  uint(a1) << 128;
        b += a2;
        return b;
    }

    // use this function in payments if coupon is provided
    function checkAndGetCoupon(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[3] calldata _pubSignals) public view returns(Coupon memory){
        uint a1 = _pubSignals[0];
        uint a2 = _pubSignals[1];
        uint _hash = constructHash(uint128(a1), uint128(a2));
        require(couponAvailable[_hash], "The coupon hash is not available");
        require(uint(uint160(msg.sender)) == _pubSignals[2] , "No front running!");
        require(verifyProof(_pA, _pB, _pC, _pubSignals), "Proof is invalid");
        return coupons[_hash];
    }    
}