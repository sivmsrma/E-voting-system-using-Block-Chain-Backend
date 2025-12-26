const hre = require("hardhat");

async function main() {
    const address = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
    const code = await hre.ethers.provider.getCode(address);
    console.log(`Code at ${address}: ${code.slice(0, 50)}...`);
    if (code === "0x") {
        console.log("ERROR: No code found at address!");
    } else {
        console.log("SUCCESS: Code found.");
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
