const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Gas Comparison (User Contracts)", function () {
  let unoptimized, optimized;
  let owner, user;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    const Unoptimized = await ethers.getContractFactory("UnoptimizedContract");
    const Optimized = await ethers.getContractFactory("OptimizedContract");

    unoptimized = await Unoptimized.deploy();
    await unoptimized.waitForDeployment();

    optimized = await Optimized.deploy();
    await optimized.waitForDeployment();
  });

  it("Deposit", async function () {
    await unoptimized.connect(user).deposit({
      value: ethers.parseEther("1"),
    });

    await optimized.connect(user).deposit({
      value: ethers.parseEther("1"),
    });
  });

  it("Withdraw", async function () {
    await unoptimized.connect(user).deposit({
      value: ethers.parseEther("1"),
    });

    await optimized.connect(user).deposit({
      value: ethers.parseEther("1"),
    });

    await unoptimized.connect(user).withdraw(
      ethers.parseEther("0.5")
    );

    await optimized.connect(user).withdraw(
      ethers.parseEther("0.5")
    );
  });

  it("Increment loop (gas heavy)", async function () {
    // Use a higher number to amplify gas differences
    await unoptimized.increment(20);
    await optimized.increment(20);
  });

  it("Toggle Active", async function () {
    await unoptimized.toggleActive();
    await optimized.toggleActive();
  });

  it("Set Fee", async function () {
    await unoptimized.setFee(ethers.parseEther("0.1"));
    await optimized.setFee(ethers.parseEther("0.1"));
  });
});