import { ethers } from "hardhat";
import { expect } from "chai";

// TODO: Teste to be included:
/**
 * 1. Royalty
 * 2. Value added services
 * 3. payment
 * 4. set metadata after payment
 * 5. Coupon for payment
 * 6. Adding and removing coupons
 * 7. 
 */

describe("Droplinked", function(){
    async function deployContract() {
        const fee = 100;
        const [owner,producer,publisher,customer] = await ethers.getSigners();
        const Droplinked = await ethers.getContractFactory("DroplinkedOperator");
        const droplinked = await Droplinked.deploy("0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000");
        await droplinked.waitForDeployment();
        let token = await ethers.getContractAt("DroplinkedToken", await droplinked.droplinkedToken());
        let base = await ethers.getContractAt("DroplinkedBase", await droplinked.droplinkedBase());
        return {droplinked, owner, producer, publisher, customer, fee, token, base};
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
    });

    describe("PublishRequest", function(){
        enum ProductType {
            DIGITAL,
            POD,
            PHYSICAL
        };
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
        enum ProductType {
            DIGITAL,
            POD,
            PHYSICAL
        };
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
        enum ProductType {
            DIGITAL,
            POD,
            PHYSICAL
        };
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
        enum ProductType {
            DIGITAL,
            POD,
            PHYSICAL
        };
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
})