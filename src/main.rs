use std::time::Instant;

use lrclib_challenger::{
    computer::{GPUComputer, Workgroups},
    context::Context,
};

async fn solve(prefix: &[u8], target: &[u8]) -> u32 {
    let context = Context::new(prefix, target).await;
    let computer = GPUComputer::new(context);
    let solution = computer
        .dispatch(Workgroups::new(128, 128, 128, 64), 12, 13)
        .await;

    println!("total solutions {}", solution[0]);

    solution[1]
}

#[tokio::main]
async fn main() {
    let prefix = b"VXMwW2qPfW2gkCNSl1i708NJkDghtAyU";
    let target =
        hex::decode("000000FF00000000000000000000000000000000000000000000000000000000").unwrap();

    let time = Instant::now();
    let solution = solve(prefix, &target).await;

    println!("solution: {}", solution);
    println!("time {:?}", time.elapsed());
}
