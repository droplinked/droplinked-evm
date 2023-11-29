pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/sha256/sha256.circom";
include "../node_modules/circomlib/circuits/bitify.circom";

template couponVerifier() {
  signal input etheruemAccount; 
  signal input secretData;
  signal output s1;
  signal output s2;
  signal sha256Hash1[128];
  signal sha256Hash2[128];
  signal hash_array[256];
  signal accountSquared <== etheruemAccount * etheruemAccount;

  component num2bits = Num2Bits(256);
  num2bits.in <== secretData;
  hash_array <== num2bits.out;
  component sha256 = Sha256(256);  
  for(var i = 0; i< 256; i++){
    sha256.in[i] <== hash_array[255-i];
  }
  for(var i = 0; i< 128; i++){
    sha256Hash1[i] <== sha256.out[127-i];
  }
  for(var i = 128; i< 256; i++){
    sha256Hash2[i-128] <== sha256.out[255-i+128];
  }
  component bits2num = Bits2Num(128);
  bits2num.in <== sha256Hash1;
  s1 <== bits2num.out;
  component bits2num2 = Bits2Num(128);
  bits2num2.in <== sha256Hash2;
  s2 <== bits2num2.out;
  
}

component main { public [etheruemAccount] } = couponVerifier();