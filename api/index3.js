const fs = require("fs");

const INPUT_FILE = "raw_output.csv";
const OUTPUT_FILE = "sorted_div100_with_count.csv";

// Read input CSV
const lines = fs.readFileSync(INPUT_FILE, "utf8").trim().split("\n");

// Parse rows (skip header)
const rows = lines.slice(1).map(line => {
  const [sr, randomNumber] = line.split(",");

  const div100 = Number(randomNumber) / 100;

  return {
    sr: Number(sr),
    randomNumber: Number(randomNumber),
    randomNumberDiv100: div100
  };
});

// 1️⃣ Count occurrences of randomNumberDiv100
const frequencyMap = new Map();

for (const row of rows) {
  const key = row.randomNumberDiv100;
  frequencyMap.set(key, (frequencyMap.get(key) ?? 0) + 1);
}

// 2️⃣ Attach occurrenceCount to each row
const enrichedRows = rows.map(row => ({
  ...row,
  occurrenceCount: frequencyMap.get(row.randomNumberDiv100)
}));

// 3️⃣ Sort by randomNumberDiv100 (ascending)
enrichedRows.sort(
  (a, b) => a.randomNumberDiv100 - b.randomNumberDiv100
);

// 4️⃣ Build CSV
const header =
  "sr.no,randomNumber,randomNumberDiv100,occurrenceCount\n";

const body = enrichedRows
  .map(r =>
    `${r.sr},${r.randomNumber},${r.randomNumberDiv100},${r.occurrenceCount}`
  )
  .join("\n");

fs.writeFileSync(OUTPUT_FILE, header + body);

console.log("✅ CSV generated:", OUTPUT_FILE);
