build zig :
	(cd wasm && zig build);
	cp ./wasm/zig-out/bin/wasm.wasm ./wasm.wasm

