// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./CouponVerifier.sol";
import "./IDroplinkedBase.sol";

/// @title Coupon struct
    /// @dev Represents a coupon with various properties
    struct Coupon {
        /// @dev Indicates if the coupon value is a percentage or a fixed amount
        bool isPercentage;
    
        /// @dev The value of the coupon
        uint value;
    
        /// @dev A hash used for verification purposes using sha256
        uint secretHash;
    
        /// @dev The address of the coupon producer
        address couponProducer;
}

contract CouponManager is CouponVerifier{
    

    mapping (uint => bool) public couponAvailable;
    mapping (uint => Coupon) public coupons;

    event CouponAdded(uint secretHash, bool isPercentage, uint value, address couponProducer);
    event CouponRemoved(uint secretHash, address couponProducer);

    /**
     * @dev Adds a coupon to the system.
     * @param _secretHash The secret hash of the coupon using sha256.
     * @param _isPercentage Flag indicating if the coupon value is a percentage or a fixed value.
     * @param _value The value of the coupon.
     */
    function addCoupon(uint _secretHash, bool _isPercentage, uint _value) public {
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

    /**
     * @dev Removes a coupon.
     * @param secretHash The hash of the coupon.
     */
    function removeCoupon(uint secretHash) public {
        // Check if the coupon exists
        require(couponAvailable[secretHash], "Coupon hash does not exist");
        
        // Check if the caller is the producer of the coupon
        require(coupons[secretHash].couponProducer == msg.sender, "Only producer can remove a coupon");
        
        // Delete the coupon and mark it as unavailable
        delete coupons[secretHash];
        couponAvailable[secretHash] = false;
        
        // Emit the CouponRemoved event
        emit CouponRemoved(secretHash, msg.sender);
    }

    /**
     * @dev Combines two uint128 values into a single uint256 value.
     * @param a1 The first uint128 value.
     * @param a2 The second uint128 value.
     * @return The combined uint256 value.
     */
    function combineUint128(uint128 a1, uint128 a2) private pure returns (uint) {
        // Shift the first value by 128 bits to the left and add the second value.
        uint b = uint(a1) << 128;
        b += a2;
        return b;
    }

    // This function checks if a coupon is available and verifies the proof and returns the coupon
    // Parameters:
    // - _pA: An array of 2 uints representing a proof
    // - _pB: A 2x2 matrix of uints representing a proof
    // - _pC: An array of 2 uints representing a proof
    // - _pubSignals: An array of 3 uints representing public signals of the proof
    // Returns:
    // - Coupon: A struct representing the coupon
    function checkAndGetCoupon(CouponProof calldata _proof) public view returns(Coupon memory) {
        uint a1 = _proof._pubSignals[0];
        uint a2 = _proof._pubSignals[1];
        uint _hash = combineUint128(uint128(a1), uint128(a2));
    
        // Check if the coupon hash is available
        require(couponAvailable[_hash], "The coupon hash is not available");
    
        // Check if the caller is the expected address in the proof
        require(uint(uint160(msg.sender)) == _proof._pubSignals[2], "No front running!");
    
        // Check if the proof is valid
        require(verifyProof(_proof._pA, _proof._pB, _proof._pC, _proof._pubSignals), "Proof is invalid");
    
        // Return the coupon
        return coupons[_hash];
    }
}