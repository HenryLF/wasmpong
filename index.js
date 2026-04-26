// node_modules/wasm-zig/dist/index.js
var WASM_TYPE = /* @__PURE__ */ ((WASM_TYPE2) => {
  WASM_TYPE2["I8"] = "i8";
  WASM_TYPE2["U8"] = "u8";
  WASM_TYPE2["F32"] = "f32";
  WASM_TYPE2["U32"] = "u32";
  return WASM_TYPE2;
})(WASM_TYPE || {});
var WasmWorker = class _WasmWorker {
  buffer = null;
  _pointers = {};
  mainCallbacks = /* @__PURE__ */ new Map();
  /** Maps exported global names to their memory addresses in the shared WASM buffer. */
  get exports() {
    return this._pointers;
  }
  worker;
  pending = /* @__PURE__ */ new Map();
  seq = 0;
  constructor() {
    this.worker = new Worker(new URL("./worker.js", import.meta.url), {
      type: "module"
    });
    this.worker.onmessage = ({ data }) => {
      if (data.type === "callback") {
        this.mainCallbacks.get(data.name)?.(...data.args ?? []);
        return;
      }
      const cb = this.pending.get(data.id);
      if (!cb) return;
      this.pending.delete(data.id);
      data.error ? cb.reject(data.error) : cb.resolve(data.result);
    };
    this.worker.onerror = (e) => console.error("WasmWorker error:", e);
  }
  /** Creates a `WasmWorker`, loads the `.wasm` binary inside a dedicated Web Worker with shared memory, and resolves once ready. */
  static async create(url, options) {
    const w = new _WasmWorker();
    await w.init(url, options);
    return w;
  }
  async init(url, options) {
    const { envImport, ...restOptions } = options ?? {};
    const callbackNames = [];
    for (const [name, fn] of Object.entries(envImport ?? {})) {
      if (typeof fn === "function") {
        this.mainCallbacks.set(name, fn);
        callbackNames.push(name);
      }
    }
    const { sab, pointers } = await this.send("init", { url, options: restOptions, callbackNames });
    this.buffer = sab;
    this._pointers = pointers;
  }
  send(type, data) {
    const id = this.seq++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, {
        resolve,
        reject
      });
      this.worker.postMessage({ id, type, ...data });
    });
  }
  ptr(key) {
    if (!this.buffer) throw new Error("not initialized");
    const ptr = this._pointers[key];
    if (ptr === void 0) throw new Error(`no pointer for "${String(key)}"`);
    return ptr;
  }
  // --- direct SAB reads ---
  /** Returns a typed array view directly into the shared WASM memory — zero-copy, synchronous. */
  getArr(key, asType, len) {
    const ptr = this.ptr(key);
    switch (asType) {
      case "u8":
        return new Uint8Array(this.buffer, ptr, len);
      case "i8":
        return new Int8Array(this.buffer, ptr, len);
      case "u32":
        return new Uint32Array(this.buffer, ptr, len);
      case "f32":
        return new Float32Array(this.buffer, ptr, len);
      default:
        throw new Error(`Unknown WASM_TYPE: ${asType}`);
    }
  }
  /** Reads a single numeric value directly from the shared WASM memory. */
  get(key, asType) {
    const ptr = this.ptr(key);
    const view = new DataView(this.buffer);
    switch (asType) {
      case "u8":
        return view.getUint8(ptr);
      case "i8":
        return view.getInt8(ptr);
      case "u32":
        return view.getUint32(ptr, true);
      case "f32":
        return view.getFloat32(ptr, true);
      default:
        throw new Error(`Unknown WASM_TYPE: ${asType}`);
    }
  }
  /** Copies pixel data out of shared WASM memory into a regular `ArrayBuffer`, ready for use with `ImageData`. */
  getImg(key, len) {
    return new Uint8ClampedArray(this.buffer, this.ptr(key), len).slice();
  }
  /** Decodes UTF-8 text directly from the shared WASM memory. */
  getText(key, len) {
    return new TextDecoder().decode(
      new Uint8Array(this.buffer, this.ptr(key), len)
    );
  }
  /** Parses a JSON string directly from the shared WASM memory. */
  getJSON(key, len) {
    try {
      return JSON.parse(this.getText(key, len));
    } catch (err) {
      console.error(`Invalid JSON: ${err}`);
    }
  }
  // --- direct SAB writes ---
  /** Writes a single numeric value directly into the shared WASM memory. */
  set(key, asType, val) {
    const ptr = this.ptr(key);
    const view = new DataView(this.buffer);
    switch (asType) {
      case "u8":
        view.setUint8(ptr, val);
        break;
      case "i8":
        view.setInt8(ptr, val);
        break;
      case "u32":
        view.setUint32(ptr, val, true);
        break;
      case "f32":
        view.setFloat32(ptr, val, true);
        break;
      default:
        throw new Error(`Unknown WASM_TYPE: ${asType}`);
    }
  }
  /** Writes multiple values into the shared WASM memory starting at the exported symbol's address. */
  setArr(key, asType, ...vals) {
    const base = this.ptr(key);
    switch (asType) {
      case "u8":
        new Uint8Array(this.buffer, base, vals.length).set(vals);
        break;
      case "i8":
        new Int8Array(this.buffer, base, vals.length).set(vals);
        break;
      case "u32":
        new Uint32Array(this.buffer, base, vals.length).set(vals);
        break;
      case "f32":
        new Float32Array(this.buffer, base, vals.length).set(vals);
        break;
      default:
        throw new Error(`Unknown WASM_TYPE: ${asType}`);
    }
  }
  /** Executes an exported WASM function in the worker thread and returns its result. */
  call(fn, ...args) {
    return this.send("call", { fn, args });
  }
  /** Terminates the underlying Web Worker and rejects any in-flight `call()` promises. */
  terminate() {
    for (const { reject } of this.pending.values()) {
      reject("Worker terminated");
    }
    this.pending.clear();
    this.worker.terminate();
  }
};

// index.ts
var scoreSpan = document.getElementById("score");
var cvs = document.getElementById("canvas");
var ctx = cvs.getContext("2d");
var wasm = await WasmWorker.create("./wasm.wasm", {
  envImport: {
    updateScore() {
      if (!wasm) return;
      const score = wasm.getArr("score", WASM_TYPE.U8, 2);
      scoreSpan.textContent = score.join("-");
    }
  },
  memoryOptions: {
    initial: 100,
    maximum: 500
  }
});
var aiSelector = document.getElementById("ai-selector");
aiSelector.value = "0";
var img_size = wasm.get("img_size", WASM_TYPE.U32);
var img_buffer_size = wasm.get("img_buffer_size", WASM_TYPE.U32);
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
      wasm.set("input", WASM_TYPE.U8, input | 1);
      break;
    case "ArrowRight":
      wasm.set("input", WASM_TYPE.U8, input | 16);
      break;
  }
});
window.addEventListener("keyup", ({ key }) => {
  const input = wasm.get("input", WASM_TYPE.U8);
  switch (key) {
    case "ArrowLeft":
      wasm.set("input", WASM_TYPE.U8, input & ~1);
      break;
    case "ArrowRight":
      wasm.set("input", WASM_TYPE.U8, input & ~16);
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
