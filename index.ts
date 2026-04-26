import { WASM_TYPE, WasmWorker } from "wasm-zig";

type wasmType = {
  init(): void;
  loop(): void;
  setAiBehavior(n: number): void;

  score: WebAssembly.Global;
  input: WebAssembly.Global;
  img_size: WebAssembly.Global;
  img_buffer: WebAssembly.Global;
  img_buffer_size: WebAssembly.Global;
};

const scoreSpan = document.getElementById("score") as HTMLSpanElement;


const cvs = document.getElementById("canvas") as HTMLCanvasElement;
const ctx = cvs.getContext("2d");
const wasm = await WasmWorker.create<wasmType>("./wasm.wasm", {
  envImport: {
    updateScore() {
      if (!wasm) return;
      const score = wasm.getArr("score", WASM_TYPE.U8, 2);
      scoreSpan.textContent = score.join("-");
    },
  },
  memoryOptions: {
    initial: 100,
    maximum: 500,
  },
});

const aiSelector = document.getElementById("ai-selector") as HTMLSelectElement;
aiSelector.value = "0";
const img_size = wasm.get("img_size", WASM_TYPE.U32);
const img_buffer_size = wasm.get("img_buffer_size", WASM_TYPE.U32);

cvs.height = img_size;
cvs.width = img_size;

await wasm.call("init");

aiSelector.addEventListener("change", () => {
  const mode = parseInt(aiSelector.value);
  if (!isNaN(mode)) wasm.call("setAiBehavior", mode);
});
aiSelector.addEventListener("input", (e) => e.preventDefault());

window.addEventListener("keydown", ({ key }) => {
  const input = wasm.get("input", WASM_TYPE.U8);
  switch (key) {
    case "ArrowLeft":
      wasm.set("input", WASM_TYPE.U8, input | 0x01);
      break;
    case "ArrowRight":
      wasm.set("input", WASM_TYPE.U8, input | 0x10);
      break;
  }
});

window.addEventListener("keyup", ({ key }) => {
  const input = wasm.get("input", WASM_TYPE.U8);
  switch (key) {
    case "ArrowLeft":
      wasm.set("input", WASM_TYPE.U8, input & ~0x01);
      break;
    case "ArrowRight":
      wasm.set("input", WASM_TYPE.U8, input & ~0x10);
      break;
  }
});

async function loop() {
  await wasm.call("loop");
  const data = wasm.getImg("img_buffer", img_buffer_size);
  ctx?.putImageData(new ImageData(data, img_size), 2, 2);
  requestAnimationFrame(loop);
}

loop();
