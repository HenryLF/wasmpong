import { context } from "esbuild";

const ctx = await context({
  entryPoints: {
    index: "./index.ts",
    worker: "./wasm-zig/src/worker.ts",
  },
  outdir: ".",
  bundle: true,
  format: "esm",
});

await ctx.watch();
