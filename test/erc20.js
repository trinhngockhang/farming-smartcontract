const { expect } = require("chai");

describe("Token contract", function () {

    let owner, address1, token, address2;
    beforeEach(async () => {
        [owner, address1, address2] = await ethers.getSigners();
        const Token = await ethers.getContractFactory("Token");
        token = await Token.deploy("Khang", "KHG", 18, [owner.address], [owner.address], owner.address);
    })

    it("Total supply is equal 0", async() => {
        const totalSupply = await token.totalSupply();
        expect(totalSupply).to.equal(0);
    });

    it("Mint to address should be right", async () => {
        await token.mint(address1.address, 5);
        const balanceOfAddress1 = await token.balanceOf(address1.address);
        expect(balanceOfAddress1).to.equal(5);
    })

    it("Only minter can mint", async () => {
        await expect(token.connect(address1).mint(address1.address, 5)).to.be.reverted;
    })

    it("Only burner can burn", async () => {
        await expect(token.connect(address1).burn(address1.address, 5)).to.be.reverted;
    })

    it("Only admin can pause", async () => {
        await expect(token.connect(address1).pause()).to.be.reverted;
    })


    it("Can not transfer after pause", async () => {
        await token.pause();
        await expect(token.mint(address1.address, 9)).to.be.reverted;
        await expect(token.burn(address1.address, 9)).to.be.reverted;
        await expect(token.transferFrom(address1.address, 9)).to.be.reverted;
    })

    it("Cap can not mint over 1 bilion", async () => {
        await expect(token.mint(address1.address, 1000000001)).to.be.reverted;
    })

});
