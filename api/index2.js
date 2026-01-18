const fs = require("fs");
const { writeFileSync, appendFileSync } = fs;


const RandomNumber = require("./crypto.js");
const { ethers } = require("ethers");
// const { writeFileSync }  = require("fs");

async function getRandomNumberHash () {
    const { randomNumber, suffix, hash} = await RandomNumber.generateRandomNumberHash();
    console.log("Generated Hash:", randomNumber, suffix, hash);
    return {randomNumber}
}

// getRandomNumberHash();


const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function runSimulation(times = 100000) {
  const frequency = new Map(); // randomNumber -> count

  // Initialize CSVs
  writeFileSync(
    "raw_output.csv",
    "sr.no,randomNumber\n"
  );

  writeFileSync(
    "output_sorted3.csv",
    "randomNumberDiv100,appearanceCount\n"
  );

  for (let i = 0; i < times; i++) {
    // await delay(100);

    const result = await getRandomNumberHash();
    const { randomNumber } = result;

    // Update frequency
    const count = (frequency.get(randomNumber) ?? 0) + 1;
    frequency.set(randomNumber, count);

    // 1️⃣ Append raw data immediately
    appendFileSync(
      "raw_output.csv",
      `${i + 1},${randomNumber}\n`
    );

    // 2️⃣ Rebuild sorted summary CSV
    const sorted = [...frequency.entries()]
      .sort((a, b) => a[0] - b[0])
      .map(([num, cnt]) => ({
        randomNumberDiv100: num / 100,
        appearanceCount: cnt
      }));

    const csv =
      "randomNumberDiv100,appearanceCount\n" +
      sorted
        .map(r => `${r.randomNumberDiv100},${r.appearanceCount}`)
        .join("\n");

    writeFileSync("output_sorted2.csv", csv);

    console.log(
      `Saved → randomNumber=${randomNumber}, count=${count}`
    );
  }

  console.log("Simulation completed");
}

runSimulation();
