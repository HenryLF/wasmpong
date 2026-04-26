import { context } from "esbuild";

const ctx = await context({
  entryPoints: {
    index: "./index.ts",
    worker: "./node_modules/wasm-zig/dist/worker.js",
  },
  outdir: ".",
  bundle: true,
  format: "esm",
});

await ctx.watch();
