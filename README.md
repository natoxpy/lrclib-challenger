# LICLIB Challenger

This program uses WGPU to execute a compute shader capable of cracking the LRCLIB challenge within seconds.

# Examples
On a Radeon RX 6700 XT, it does 134,217,728 SHA-256 hashes, finds 6 solutions, and returns the first solution it found.
This used the following parameters. 

`prefix` VXMwW2qPfW2gkCNSl1i708NJkDghtAyU

`target` 000000FF00000000000000000000000000000000000000000000000000000000

![image](https://github.com/user-attachments/assets/a7c56c0e-f963-4325-b0ce-76fb641faff1)


# Usage
You can git clone this repository, and execute with `cargo run`. Check the `main.rs` file to see what parameters you can modify in `computer.dispatch()` 
there you can change the workgroups which is how big the batch of hashes your GPU will be requested with. 

Do not modify the last number which stays at `64` labeled `threads`, if you did modify it, go to shaders, into `nonce-hash.wgsl`, and modify the constant 
`block_x` with the same number. The program needs it to be able to properly calculate the offset of each batch.
