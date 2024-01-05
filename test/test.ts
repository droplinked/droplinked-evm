import { ethers } from "hardhat";
import { expect } from "chai";
import { DroplinkedBase, DroplinkedOperator } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

// TODO: Teste to be included:
/**
 * 1. Coupon for payment
 */
enum ProductType {
    DIGITAL,
    POD,
    PHYSICAL
};
type Beneficiary = {
    isPercentage: boolean; 
    value: number;
    wallet: string;
}
describe("Droplinked", function(){
    async function deployContract() {
        const fee = 100;
        const [owner,producer,publisher,customer, beneficiary1, beneficiary2, royaltyAcc] = await ethers.getSigners();
        const Droplinked = await ethers.getContractFactory("DroplinkedOperator");
        const droplinked = await Droplinked.deploy("0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000");
        await droplinked.waitForDeployment();
        let token = await ethers.getContractAt("DroplinkedToken", await droplinked.droplinkedToken());
        let base = await ethers.getContractAt("DroplinkedBase", await droplinked.droplinkedBase());
        return {droplinked, owner, producer, publisher, customer, fee, token, base, beneficiary1, beneficiary2,royaltyAcc};
    }

    describe("Deployment", function(){
        it("Should set the right owner", async function(){
            const {droplinked,owner} = await deployContract();
            expect(await droplinked.owner()).to.equal(await owner.getAddress());
        });
        it("Should set the right fee", async function(){
            const {droplinked,fee} = await deployContract();
            expect(await droplinked.getFee()).to.equal(fee);
        });
    });

    describe("Set & Update heartbeat", function(){
        it("Should update the heartbeat with owner account", async function(){
            const {droplinked,owner, token} = await deployContract();
            await droplinked.connect(owner).setHeartBeat(4000);
            expect(await token.getHeartBeat()).to.equal(4000);
        });

        it("should not update the heartbeat with other account", async function(){
            const {droplinked,producer, token} = await deployContract();
            await expect(droplinked.connect(producer).setHeartBeat(4000)).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Set & update fee", function(){
        it("Should update the fee to given number using owner account", async function(){
            const {droplinked,owner} = await deployContract();
            await droplinked.connect(owner).setFee(200);
            expect(await droplinked.getFee()).to.equal(200);
        });

        it("Should not update the fee to given number using other account", async function(){
            const {droplinked,producer} = await deployContract();
            await expect(droplinked.connect(producer).setFee(200)).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Mint", function(){
        it("Should mint 5000 tokens", async function(){
            const {droplinked,producer, token} = await deployContract();
            enum ProductType {
                DIGITAL,
                POD,
                PHYSICAL
            };
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            expect(await token.balanceOf(await producer.getAddress(), 1)).to.equal(5000);
        });
        it("Should mint the same product with the same token_id", async function(){
            const {droplinked,producer, token} = await deployContract();
            enum ProductType {
                DIGITAL,
                POD,
                PHYSICAL
            };
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            expect(await token.balanceOf(await producer.getAddress(), 1)).to.equal(5000*2);
        });
        it("Should set the right product metadata", async function(){
            const {droplinked,producer, base} = await deployContract();
            enum ProductType {
                DIGITAL,
                POD,
                PHYSICAL
            };
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            let result = (await base.getMetadata(1, producer));
            expect(result[0]).to.equal(100n);
            expect(result[1]).to.equal(2300n);
            expect(result[2]).to.equal(0n);
            expect(result[3]).to.equal(await producer.getAddress());            
        });

        it("should set the right beneficiaries when minting", async function(){
            const {droplinked,producer, base} = await deployContract();
            type Beneficiary = {
                isPercentage: boolean
                value: number,
                wallet: string,
            }
            let beneficiaries: Beneficiary[] = [];
            // push 3 beneficiaries
            for(let i = 0; i < 3; i++){
                beneficiaries.push({isPercentage: false, value: i*100, wallet: await producer.getAddress()});
            }
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), beneficiaries, true, 500);
            let result = (await base.getBeneficariesList(1, await producer.getAddress()));
            expect((await base.getBeneficiary(result[0])).value).to.equal(0);
            expect((await base.getBeneficiary(result[1])).value).to.equal(100);
            expect((await base.getBeneficiary(result[2])).value).to.equal(200);
            expect((await base.getBeneficiary(result[0])).wallet).to.equal(await producer.getAddress());
            expect((await base.getBeneficiary(result[1])).wallet).to.equal(await producer.getAddress());
            expect((await base.getBeneficiary(result[2])).wallet).to.equal(await producer.getAddress());
            expect((await base.getBeneficiary(result[0])).isPercentage).to.equal(false);
            expect((await base.getBeneficiary(result[1])).isPercentage).to.equal(false);
            expect((await base.getBeneficiary(result[2])).isPercentage).to.equal(false);
        });
    });

    describe("PublishRequest", function(){
        
        it("Should publish a request", async function(){
            const {droplinked,producer,publisher, base} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, producer.address, ProductType.DIGITAL, producer.address, [], true, 500);
            await droplinked.connect(publisher).publish_request(producer.address, 1);
            expect((await base.getRequest(1)).publisher).to.equal(await publisher.getAddress());
        });
        it("Should publish publish a request with the right data", async function(){
            const {droplinked,producer,publisher,base} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(await producer.getAddress(),1);
            expect((await base.getRequest(1)).publisher).to.equal(await publisher.getAddress());
            expect((await base.getRequest(1)).producer).to.equal(await producer.getAddress());
            expect((await base.getRequest(1)).tokenId).to.equal(1);
            expect((await base.getRequest(1)).accepted).to.equal(false);
        });
        it("Should publish a request and put it in the incoming requests of producer", async function(){
            const {droplinked,producer,publisher,base} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(await producer.getAddress(),1);
            expect(await base.getProducersRequests(await producer.getAddress(),1)).to.equal(true);
        });
        it("Should publish a request and put it in the outgoing requests of publisher", async function(){
            const {droplinked,producer,publisher,base} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(await producer.getAddress(),1);
            expect(await base.getPublishersRequests(await publisher.getAddress(),1)).to.equal(true);
        });
        it("Should not publish a request twice", async function(){
            const {droplinked,producer,publisher} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(await producer.getAddress(),1);
            await expect(droplinked.connect(publisher).publish_request(await producer.getAddress(),1)).to.be.revertedWithCustomError(droplinked,"AlreadyRequested");
        });
    });

    describe("CancelRequest", function(){
        
        it("Should cancel a request", async function(){
            const {droplinked,producer,publisher, base} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(producer.getAddress(),1);
            await droplinked.connect(publisher).cancel_request(1);
            expect((await base.getPublishersRequests(publisher.getAddress(),1))).to.equal(false);
            expect((await base.getProducersRequests(producer.getAddress(),1))).to.equal(false);
        });
        it("Should not cancel a request if it is not the publisher", async function(){
            const {droplinked,producer,publisher,customer} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(producer.getAddress(),1);
            await expect(droplinked.connect(customer).cancel_request(1)).to.be.revertedWithCustomError(droplinked,"AccessDenied");
        });
        it("Should not cancel a request if it is approved", async function(){
            const {droplinked,producer,publisher,customer} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(producer.getAddress(),1);
            await droplinked.connect(producer).approve_request(1);
            await expect(droplinked.connect(publisher).cancel_request(1)).to.be.revertedWithCustomError(droplinked,"RequestIsAccepted");
        });
    });

    describe("AcceptRequest", function(){
        
        it("Should accept a request", async function(){
            const {droplinked,producer,publisher,base} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(producer.getAddress(),1);
            await droplinked.connect(producer).approve_request(1);
            expect((await base.getRequest(1)).accepted).to.equal(true);
        });
        it("Should not accept a request if it is not the producer", async function(){
            const {droplinked,producer,publisher,customer} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(producer.getAddress(),1);
            await expect(droplinked.connect(customer).approve_request(1)).to.be.revertedWithCustomError(droplinked,"RequestNotfound");
        });
    });

    describe("DisapproveRequest", function(){
        it("Should disapprove a request", async function(){
            const {droplinked,producer,publisher,base} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(producer.getAddress(),1);
            await droplinked.connect(producer).disapprove(1);
            expect((await base.getRequest(1)).accepted).to.equal(false);
        });
        it("Should not disapprove a request if it is not the producer", async function(){
            const {droplinked,producer,publisher,customer} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(publisher).publish_request(producer.getAddress(),1);
            await expect(droplinked.connect(customer).disapprove(1)).to.be.revertedWithCustomError(droplinked,"AccessDenied");
        });
    });

    describe("ERC20 Tokens", function(){
        it("should add an erc20 token to the contract", async function(){
            // deploy
            const ERC20 = await ethers.getContractFactory("myERC20Token");
            const erc20 = await ERC20.deploy();
            const {droplinked,base} = await deployContract();
            await droplinked.addERC20Contract(await erc20.getAddress());
            expect(await base.isERC20addressIncluded(await erc20.getAddress())).to.be.equal(true);
        });

        it("should remove an erc20 token to the contract", async function(){
            // deploy
            const ERC20 = await ethers.getContractFactory("myERC20Token");
            const erc20 = await ERC20.deploy();
            const {droplinked,base} = await deployContract();
            await droplinked.addERC20Contract(await erc20.getAddress());
            await droplinked.removeERC20Contract(await erc20.getAddress());
            expect(await base.isERC20addressIncluded(await erc20.getAddress())).to.be.equal(false);
        });

        it("should not accept a non erc20 contract", async function(){
            // deploy
            const ERC20 = await ethers.getContractFactory("DroplinkedToken");
            const erc20 = await ERC20.deploy();
            const {droplinked,base} = await deployContract();
            await expect(droplinked.addERC20Contract(await erc20.getAddress())).to.be.revertedWith("Not a valid ERC20 contract");
        });
    });

    describe("Royalty check" , function(){
        it("should add royalty for a product while minting", async function(){
            const {droplinked,producer,base} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            expect((await base.getIssuer(1)).royalty).to.equal(500);
            expect((await base.getIssuer(1)).issuer).to.equal(await producer.getAddress());
        });

        it("should not update issuer info for the same product in minting", async function(){
            const {droplinked,producer,base} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 600);
            expect((await base.getIssuer(1)).royalty).to.equal(500);
            expect((await base.getIssuer(1)).issuer).to.equal(await producer.getAddress());
        });
    });   
    
    describe("Set Metadata for purchased products", function(){
        it("should error if we want to set metadata on a product which already have one", async function(){
            const {droplinked,producer,publisher} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await expect(droplinked.connect(producer).setMetadataAfterPurchase(100, 200, [], 1, await publisher.getAddress())).to.be.revertedWithCustomError(droplinked, "CannotChangeMetata");
        });
        it("should remove metadata", async function(){
            const {droplinked,producer} = await deployContract();
            await droplinked.connect(producer).mint("ipfs://randomhash", 100, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
            await expect(droplinked.connect(producer).removeMetadata(1)).not.to.reverted;
        });
    });

    describe("Coupon", function(){
        it("Should add a coupon", async function(){
            const {producer,base} = await deployContract();
            await base.connect(producer).addCoupon(41239141235, true, 400);
            expect((await base.getCoupon(41239141235)).couponProducer).to.equal(await producer.getAddress());
            expect((await base.getCoupon(41239141235)).value).to.equal(400);
            expect((await base.getCoupon(41239141235)).isPercentage).to.equal(true);
            expect((await base.getCoupon(41239141235)).secretHash).to.equal(41239141235);
        });

        it("Should not add a coupon twice", async function(){
            const CouponManager = await ethers.getContractFactory("CouponManager");
            const couponManager = await CouponManager.deploy();
            await couponManager.addCoupon(41239141235, true, 400);
            await expect(couponManager.addCoupon(41239141235, true, 400)).to.revertedWithCustomError(couponManager, "CouponAlreadyAdded");
        });

        it("should remove a coupon", async function(){
            const {producer,base} = await deployContract();
            await base.connect(producer).addCoupon(41239141235, true, 400);
            await base.connect(producer).removeCoupon(41239141235);
            expect((await base.getCoupon(41239141235)).couponProducer).to.equal("0x0000000000000000000000000000000000000000");
            expect((await base.getCoupon(41239141235)).value).to.equal(0);
            expect((await base.getCoupon(41239141235)).isPercentage).to.equal(false);
            expect((await base.getCoupon(41239141235)).secretHash).to.equal(0);
        });
    });

    // check for: price, ratio, amount, affiliate, POD, coupon, royalty, 
    describe("Payment", function(){
        async function recordProduct(droplinked: DroplinkedOperator, producer: SignerWithAddress, price: number){
            await droplinked.connect(producer).mint("ipfs://randomhash", price, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
        }
        async function recordProduct2(droplinked: DroplinkedOperator, producer: SignerWithAddress, price: number){
            await droplinked.connect(producer).mint("ipfs://randomhash2", price, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
        }
        async function recordProductPOD(droplinked: DroplinkedOperator, producer: SignerWithAddress, price: number){
            await droplinked.connect(producer).mint("ipfs://randomhash2", price, 2300, 5000, await producer.getAddress(), ProductType.POD, await producer.getAddress(), [], true, 500);
        }
        async function recordWithBeneficiariesPercent(droplinked: DroplinkedOperator, producer: SignerWithAddress, price: number, beneficiary: SignerWithAddress){
            let beneficaries: Beneficiary[] = [
                {
                    isPercentage: true,
                    value: 100,
                    wallet: await beneficiary.getAddress()
                }
            ];
            await droplinked.connect(producer).mint("ipfs://randomhash3", price, 100, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), beneficaries, true, 500);
        }

        async function recordWithBeneficiariesValue(droplinked: DroplinkedOperator, producer: SignerWithAddress, price: number, beneficiary: SignerWithAddress){
            let beneficaries: Beneficiary[] = [
                {
                    isPercentage: false,
                    value: 100,
                    wallet: await beneficiary.getAddress()
                }
            ];
            await droplinked.connect(producer).mint("ipfs://randomhash4", price, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), beneficaries, true, 500);
        }
        async function recordWithBeneficiariesValueAndPercent(droplinked: DroplinkedOperator, producer: SignerWithAddress, price: number, beneficiary: SignerWithAddress, beneficary2: SignerWithAddress){
            let beneficaries: Beneficiary[] = [
                {
                    isPercentage: false,
                    value: 100,
                    wallet: await beneficiary.getAddress()
                },
                {
                    isPercentage: true,
                    value: 100,
                    wallet: await beneficary2.getAddress()
                }
            ];
            await droplinked.connect(producer).mint("ipfs://randomhash5", price, 2300, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), beneficaries, true, 500);
        }
        async function recordWithCoupon(droplinked: DroplinkedOperator, producer: SignerWithAddress, base: DroplinkedBase){
            // price: 1$
            // coupon: 50%
            await base.connect(producer).addCoupon(412304, true, 100);
            await droplinked.connect(producer).mint("ipfs://randomhash124", 100, 100, 5000, await producer.getAddress(), ProductType.DIGITAL, await producer.getAddress(), [], true, 500);
        }
        function convertToUSD(price: number){
            return BigInt(Math.floor(1e18 * price));
        }
        async function getReadyForPayment(){
            const {producer,base, droplinked, customer, publisher, fee, owner, token, beneficiary1, beneficiary2, royaltyAcc} = await deployContract();
            await recordProduct(droplinked, producer,100);
            await recordProduct2(droplinked, producer,100);
            await recordWithBeneficiariesPercent(droplinked, producer, 100, beneficiary1); // < -- 1% beneficiary share
            await recordWithBeneficiariesValue(droplinked, producer, 200, beneficiary1); // < -- 1$ beneficiary share, 2$ product price
            await recordWithBeneficiariesValueAndPercent(droplinked, producer, 200, beneficiary1, beneficiary2); // < -- 1$ beneficiary1, 1% beneficiary2, 1% droplinked
            await recordProductPOD(droplinked, producer,100);
            await recordWithCoupon(droplinked, producer, base); //token id 7 <-- 50% coupon , 1$ product -> 0.01$ droplinked, 0.49$ producer, 0.5% no need
            // <-- 0.5$ should be payed
            // <-- 0.05$ droplinked & 0.45$ producer
            return {producer,base, droplinked, customer, publisher, fee, owner, token, beneficiary1, beneficiary2, royaltyAcc};
        }
        function getFakeProof(){
            type proof = {
                _pA: [number, number],
                _pB: [[number, number], [number, number]],
                _pC: [number, number],
                _pubSignals: [number, number, number],
                provided: boolean
           }
           let _proof: proof = {
                _pA: [0,0],
                _pB: [[0,0],[0,0]],
                _pC: [0,0],
                _pubSignals: [0,0,0],
                provided: false
            };
            return _proof;
        }

        function getProofFor(secretHash: number){
            type proof = {
                _pA: [number, number],
                _pB: [[number, number], [number, number]],
                _pC: [number, number],
                _pubSignals: [number, number, number],
                provided: boolean
           }
           let _proof: proof = {
                _pA: [0,0],
                _pB: [[0,0],[0,0]],
                _pC: [0,0],
                _pubSignals: [0,0,0],
                provided: false
            };
            // calculate the proof here and update _proof
            // TODO:
            
            return _proof;
        }

        it("Should divide funds among people ( Test1: just TBD )", async function(){
            const {producer,base, droplinked, customer, publisher} = await getReadyForPayment();
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues = [100];
            let tbdReceivers = [publisher.getAddress()];
            const publisherFunds = await ethers.provider.getBalance(await publisher.getAddress());
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [];
            let proof = getFakeProof();
            await droplinked.connect(customer).droplinkedPurchase(_shop, chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("1")});
            const publisherFundsAfter = await ethers.provider.getBalance(await publisher.getAddress());
            expect(publisherFundsAfter - publisherFunds).to.equal(convertToUSD(1)); // <- 1$ tbd
        });

        it("Should divide funds among people ( Test2: 1 minted product without TBD )", async function(){
            const {producer,base, droplinked, customer, publisher} = await getReadyForPayment();
            // mitn the NFT
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            const producerFunds = await ethers.provider.getBalance(await producer.getAddress());
            const droplinkedFunds = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 1,
                    id: 1,
                    isAffiliate: false
                }
            ];
            let proof = getFakeProof();
            await droplinked.connect(customer).droplinkedPurchase(_shop, chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("1")});
            const producerFundsAfter = await ethers.provider.getBalance(await producer.getAddress());
            const droplinkedFundsAfter = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            expect(producerFundsAfter - producerFunds).to.equal(convertToUSD(0.99)); // <-- 0.99$ for producer
            expect(droplinkedFundsAfter - droplinkedFunds).to.equal(convertToUSD(0.01)); // <-- 0.01% for droplinked
        });

        it("Should not divide funds among people ( Test3: 1 minted product with wrong tokenId without TBD )", async function(){
            const {producer,base, droplinked, customer, publisher} = await getReadyForPayment();
            // mitn the NFT
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 1,
                    id: 5,
                    isAffiliate: false
                }
            ];
            let proof = getFakeProof();
            await expect(droplinked.connect(customer).droplinkedPurchase(_shop, chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("1")})).to.be.reverted;
        });
        it("Should not divide funds among people ( Test4: 1 minted product with more than valid amount without TBD )", async function(){
            const {producer,base, droplinked, customer, publisher} = await getReadyForPayment();
            // mitn the NFT
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 100000,
                    id: 1,
                    isAffiliate: false
                }
            ];
            let proof = getFakeProof();
            await expect(droplinked.connect(customer).droplinkedPurchase(_shop, chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("1")})).to.be.reverted;
        });

        it("Should not divide funds among people ( Test5: 1 affiliate POD with without TBD )", async function(){
            const {producer,base, droplinked, customer, publisher} = await getReadyForPayment();
            await droplinked.connect(publisher).publish_request(await producer.getAddress(), 6);
            await droplinked.connect(producer).approve_request(1);
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 1,
                    id: 1,
                    isAffiliate: true
                }
            ];
            let proof = getFakeProof();
            await expect(droplinked.connect(customer).droplinkedPurchase(_shop, chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("1")})).to.be.reverted;
        });
        
        it("Should divide funds among people ( Test6: more than 1 minted product without TBD )", async function(){
            const {producer,base, droplinked, customer, publisher} = await getReadyForPayment();
            // mitn the NFT
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            const producerFunds = await ethers.provider.getBalance(await producer.getAddress());
            const droplinkedFunds = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 1,
                    id: 1,
                    isAffiliate: false
                },
                {
                    amount: 1,
                    id: 2,
                    isAffiliate: false
                }
            ];
            let proof = getFakeProof();
            await droplinked.connect(customer).droplinkedPurchase(_shop, chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("2")});
            const producerFundsAfter = await ethers.provider.getBalance(await producer.getAddress());
            const droplinkedFundsAfter = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            expect(producerFundsAfter - producerFunds).to.equal(convertToUSD(1.98)); //<-- 2*0.99$ for producer
            expect(droplinkedFundsAfter - droplinkedFunds).to.equal(convertToUSD(0.02)); //<-- 0.02$ for droplinked
        });
        it("Should divide funds among people ( Test7: 1 minted product with one beneficiary with percentage without TBD )", async function(){
            const {producer,base, droplinked, customer, beneficiary1} = await getReadyForPayment();
            // mitn the NFT
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            const producerFunds = await ethers.provider.getBalance(await producer.getAddress());
            const droplinkedFunds = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            const beneficaryFunds = await ethers.provider.getBalance(await beneficiary1.getAddress());
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 1,
                    id: 3,
                    isAffiliate: false
                }
            ];
            let proof = getFakeProof();
            await droplinked.connect(customer).droplinkedPurchase(_shop, chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("1")});
            const producerFundsAfter = await ethers.provider.getBalance(await producer.getAddress());
            const beneficiaryFundsAfter = await ethers.provider.getBalance(await beneficiary1.getAddress());
            const droplinkedFundsAfter = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            expect(producerFundsAfter - producerFunds).to.equal(convertToUSD(0.98)); //<-- 98% for producer
            expect(droplinkedFundsAfter - droplinkedFunds).to.equal(convertToUSD(0.01)); // <-- 1% for droplinked
            expect(beneficiaryFundsAfter - beneficaryFunds).to.equal(convertToUSD(0.01)); // <-- 1% for beneficiary
        });
        it("Should divide funds among people ( Test8: 1 minted product with one beneficiary with value without TBD )", async function(){
            const {producer,base, droplinked, customer, beneficiary1} = await getReadyForPayment();
            // mitn the NFT
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            const producerFunds = await ethers.provider.getBalance(await producer.getAddress());
            const droplinkedFunds = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            const beneficaryFunds = await ethers.provider.getBalance(await beneficiary1.getAddress());
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 1,
                    id: 4,
                    isAffiliate: false
                }
            ];
            let proof = getFakeProof();
            await droplinked.connect(customer).droplinkedPurchase(_shop, chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("2")});
            const producerFundsAfter = await ethers.provider.getBalance(await producer.getAddress());
            const beneficiaryFundsAfter = await ethers.provider.getBalance(await beneficiary1.getAddress());
            const droplinkedFundsAfter = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            expect(producerFundsAfter - producerFunds).to.equal(convertToUSD(0.98)); //<-- 0.98$ for producer
            expect(droplinkedFundsAfter - droplinkedFunds).to.equal(convertToUSD(0.02)); // <-- 0.02$ for droplinked
            expect(beneficiaryFundsAfter - beneficaryFunds).to.equal(convertToUSD(1)); // <-- 1$ for beneficiary
        });
        it("Should divide funds among people ( Test9: 1 minted product with one beneficiary with value and another with percent without TBD )", async function(){
            const {producer,base, droplinked, customer, beneficiary1, beneficiary2} = await getReadyForPayment();
            // mitn the NFT
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            const producerFunds = await ethers.provider.getBalance(await producer.getAddress());
            const droplinkedFunds = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            const beneficaryFunds = await ethers.provider.getBalance(await beneficiary1.getAddress());
            const beneficary2Funds = await ethers.provider.getBalance(await beneficiary2.getAddress());
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 1,
                    id: 5,
                    isAffiliate: false
                }
            ];
            //1$ beneficiary1, 1% beneficiary2, 1% droplinked
            let proof = getFakeProof();
            await droplinked.connect(customer).droplinkedPurchase(_shop, chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("2")});
            const producerFundsAfter = await ethers.provider.getBalance(await producer.getAddress());
            const beneficiaryFundsAfter = await ethers.provider.getBalance(await beneficiary1.getAddress());
            const beneficiary2FundsAfter = await ethers.provider.getBalance(await beneficiary2.getAddress());
            const droplinkedFundsAfter = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            expect(producerFundsAfter - producerFunds).to.equal(convertToUSD(0.96)); //<-- 0.96$ for producer
            expect(droplinkedFundsAfter - droplinkedFunds).to.equal(convertToUSD(0.02)); // <-- 0.02$ for droplinked
            expect(beneficiaryFundsAfter - beneficaryFunds).to.equal(convertToUSD(1)); // <-- 1$ for beneficiary
            expect(beneficiary2FundsAfter - beneficary2Funds).to.equal(convertToUSD(0.02)); // <-- 0.02$ for beneficiary2
        });
        it("Should divide funds among people ( Test10: 1 affiliated with one beneficiary with percentage without TBD )", async function(){
            const {producer, droplinked, customer, beneficiary1, publisher} = await getReadyForPayment();
            // publish request
            await droplinked.connect(publisher).publish_request(await producer.getAddress(), 3);
            // accept request
            await droplinked.connect(producer).approve_request(1);
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            const producerFunds = await ethers.provider.getBalance(await producer.getAddress());
            const droplinkedFunds = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            const beneficaryFunds = await ethers.provider.getBalance(await beneficiary1.getAddress());
            const publisherFunds = await ethers.provider.getBalance(await publisher.getAddress());
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 1,
                    id: 1,
                    isAffiliate: true
                }
            ];
            let proof = getFakeProof();
            await droplinked.connect(customer).droplinkedPurchase(await publisher.getAddress(), chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("1")});
            const producerFundsAfter = await ethers.provider.getBalance(await producer.getAddress());
            const beneficiaryFundsAfter = await ethers.provider.getBalance(await beneficiary1.getAddress());
            const publisherFundsAfter = await ethers.provider.getBalance(await publisher.getAddress());
            const droplinkedFundsAfter = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            expect(publisherFundsAfter - publisherFunds).to.equal(convertToUSD(0.01)); // <-- 0.01$ for publisher
            expect(beneficiaryFundsAfter - beneficaryFunds).to.equal(convertToUSD(0.01)); // <-- 0.01$ for beneficiary
            expect(droplinkedFundsAfter - droplinkedFunds).to.equal(convertToUSD(0.01)); // <-- 0.01$ for droplinked
            expect(producerFundsAfter - producerFunds).to.equal(convertToUSD(0.97)); //<-- 0.97$ for producer
        });
        it("Should divide funds among people ( Test10: royalty test without TBD )", async function(){
            const {producer,base, droplinked, customer, publisher, royaltyAcc, beneficiary1} = await getReadyForPayment();
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 1,
                    id: 3,
                    isAffiliate: false
                }
            ];
            let proof = getFakeProof();
            await droplinked.connect(royaltyAcc).droplinkedPurchase(_shop, chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("1")});
            let beneficaries: Beneficiary[] = [
                {
                    isPercentage: true,
                    value: 100,
                    wallet: await beneficiary1.getAddress()
                }
            ];
            await droplinked.connect(royaltyAcc).setMetadataAfterPurchase(100, 0, beneficaries, 3, await royaltyAcc.getAddress());
            const producerFunds = await ethers.provider.getBalance(await producer.getAddress());
            const beneficiary1Funds = await ethers.provider.getBalance(await beneficiary1.getAddress());
            const royaltyAccFunds = await ethers.provider.getBalance(await royaltyAcc.getAddress());
            const droplinkedFunds = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            await droplinked.connect(customer).droplinkedPurchase(await royaltyAcc.getAddress(), chainLinkRoundId, 0, tbdValues, tbdReceivers, cartItems, proof, "Hello", {value: ethers.parseEther("1")});
            const producerFundsAfter = await ethers.provider.getBalance(await producer.getAddress());
            const beneficiary1FundsAfter = await ethers.provider.getBalance(await beneficiary1.getAddress());
            const royaltyAccFundsAfter = await ethers.provider.getBalance(await royaltyAcc.getAddress());
            const droplinkedFundsAfter = await ethers.provider.getBalance("0x89281F2dA10fB35c1Cf90954E1B3036C3EB3cc78");
            expect(royaltyAccFundsAfter - royaltyAccFunds).to.equal(convertToUSD(0.93)); // <-- 0.93$ for current owner
            expect(beneficiary1FundsAfter - beneficiary1Funds).to.equal(convertToUSD(0.01)); // <-- 0.01$ for beneficiary
            expect(droplinkedFundsAfter - droplinkedFunds).to.equal(convertToUSD(0.01)); // <-- 0.01$ for droplinked
            expect(producerFundsAfter - producerFunds).to.equal(convertToUSD(0.05)); //<-- 0.05$ for producer (royalty)
        });

        it("Should divide funds among people ( Test11: A simple recorded product with a coupon provided )", async function(){
            const {producer,base, droplinked, customer, publisher, royaltyAcc, beneficiary1} = await getReadyForPayment();
            let _shop = await producer.getAddress();
            let chainLinkRoundId = 1;
            let tbdValues: number[] = [];
            let tbdReceivers: string[] = [];
            let cartItems: {id: number,amount: number,isAffiliate:boolean}[] = [
                {
                    amount: 1,
                    id: 7,
                    isAffiliate: false
                }
            ];
            let proof = getFakeProof();


        });

    });
})