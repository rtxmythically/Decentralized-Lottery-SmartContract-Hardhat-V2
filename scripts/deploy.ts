import { ethers, run } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const ScratchLotteryV2 = await ethers.getContractFactory("ScratchLotteryV2");
    const lottery = await ScratchLotteryV2.deploy();  // 不再傳入 constructor arguments

    const receipt = await lottery.deploymentTransaction()?.wait();
    if (!receipt) {
        throw new Error("Deployment transaction receipt not found");
    }

    console.log("Lottery deployed to:", lottery.target);

    // 等待 5 個區塊確認
    await lottery.deploymentTransaction()?.wait(5);

    // 驗證合約
    try {
        await run("verify:verify", {
            address: lottery.target,
            constructorArguments: [],  // 無建構子參數
        });
        console.log("Contract verified successfully");
    } catch (error) {
        console.error("Verification failed:", error);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
