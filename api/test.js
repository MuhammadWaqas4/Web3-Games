const runSimulation = () =>{

    const plaintext = "7921";


    const maxMultiplier = 10000 / plaintext;
    console.log("Simulation started", maxMultiplier);

    console.log("Simulation started", parseInt(165999/1000));
}


// runSimulation();


const k = 0.039;
const p = 1.5;

function multiplierFromMs(t) {
  let currentMultiplier = 1;
  const plaintext = "7921";

  const maxMultiplier = 10000 / plaintext;

  if (t <= 20000) { // 20s
    currentMultiplier =
      1 +
      0.1 * Math.min(t, 10000) +
      0.2 * Math.max(0, Math.min(t - 10000, 5000)) +
      0.2 * Math.max(0, Math.min(t - 15000, 5000));
  } else {
    currentMultiplier = 4 * (1 + k * ((t - 20000) / 1000) ** p);
  }

  console.log("Simulation started", currentMultiplier, ": ", maxMultiplier );


  return currentMultiplier;
}


function multiplierFromMs1(t) {
    let currentMultiplier = 1;
    const plaintext = "7921";
  
    const maxMultiplier = 10000 / plaintext;
  
    if (t <= 20) {
      currentMultiplier =
        1 +
        0.1 * Math.min(t, 10) +
        0.2 * Math.max(0, Math.min(t - 10, 5)) +
        0.2 * Math.max(0, Math.min(t - 15, 5));
    } else {
      currentMultiplier = 4 * (1 + k * (t - 20) ** p);
    }
  
    console.log("Simulation started111", currentMultiplier, ": ", maxMultiplier );

        let currentMultiplierFloat = parseFloat(currentMultiplier.toFixed(2));
        let maxMultiplierFloat = parseFloat(maxMultiplier.toFixed(2));

        if (currentMultiplierFloat < maxMultiplierFloat) {
        console.log("not crashed");
        }
        else{
        console.log("crashed" );
        }
  
    return currentMultiplier;
  }

// multiplierFromMs(2928);
const val = parseFloat(2928 / 1000);
console.log("Simulation started11133333", val );

multiplierFromMs1(val);
