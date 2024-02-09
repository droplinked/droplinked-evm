// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;

enum ProductType {
    DIGITAL,
    POD,
    PHYSICAL
}

struct Request {
    uint256 tokenId;
    address producer;
    address publisher;
    bool accepted;
}
struct Beneficiary{
    bool isPercentage; 
    uint256 value;
    address wallet;
}

struct CouponProof {
    uint256[2] _pA;
    uint256[2][2] _pB;
    uint256[2] _pC;
    uint256[3] _pubSignals;
    bool provided;
}

struct PurchaseData {
    uint id;
    uint amount;
    bool isAffiliate;
}

struct Issuer{
    address issuer;
    uint royalty;
}

struct Coupon {
    bool isPercentage;
    uint value;
    uint secretHash;
    address couponProducer;
}