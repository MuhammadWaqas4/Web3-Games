const RandomNumber = require("./crypto.js");
const { ethers } = require("ethers");
const { writeFileSync }  = require("fs");

async function getRandomNumberHash () {
    const { randomNumber, suffix, hash} = await RandomNumber.generateRandomNumberHash();
    console.log("Generated Hash:", randomNumber, suffix, hash);
    return {randomNumber}
}

// getRandomNumberHash();

const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function runSimulation(times = 1000) {
    const rows = [];
    const frequency = new Map(); // randomNumber -> count

    // await delay(15000);

    for (let i = 0; i < times; i++) {
    await delay(7000);
      const result = await getRandomNumberHash();
      console.log("Generated Hash:", result);
  
      // Count frequency
      const count = (frequency.get(result.randomNumber) ?? 0) + 1;
      frequency.set(result.randomNumber, count);
      console.log("Generated Hash:", result, count);
  
      rows.push(result);
    }

    console.log("Generated rows:", rows);

  
    // Add appearanceCount + derived value (randomNumber / 100)
    const finalRows = rows.map(r => ({
      ...r,
      appearanceCount: frequency.get(r.randomNumber),
      randomNumberDiv100: r.randomNumber / 100
    }));
  
    // 👉 Sort by randomNumber (ascending)
    finalRows.sort((a, b) => a.randomNumber - b.randomNumber);
  
    // Build CSV
    const header =
      "randomNumberDiv100,appearanceCount\n";
  
    const csv =
      header +
      finalRows
        .map(r =>
          [
            r.randomNumberDiv100,
            r.appearanceCount
          ].join(",")
        )
        .join("\n");
  
    writeFileSync("output_sorted2.csv", csv);
  
    console.log("Done — saved to output_sorted1.csv (sorted by randomNumber)");
  }
  
  // runSimulation();

  console.log("time", 1234/1000);