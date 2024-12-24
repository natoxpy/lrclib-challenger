use gpu_compute::WGPUContext;
use wgpu::{BindGroup, CommandEncoder};

use crate::context::Context;

pub struct GPUComputer {
    pub context: Context,
}

#[derive(Debug, Clone, Copy)]
pub struct Workgroups {
    pub x: u32,
    pub y: u32,
    pub z: u32,
    pub threads: u32,
}

fn format(n: u32) -> String {
    n.to_string()
        .as_bytes()
        .rchunks(3)
        .rev()
        .map(std::str::from_utf8)
        .collect::<Result<Vec<&str>, _>>()
        .unwrap()
        .join(",")
}

impl Workgroups {
    pub fn new(x: u32, y: u32, z: u32, threads: u32) -> Self {
        Self { x, y, z, threads }
    }

    pub fn total(&self) -> u32 {
        self.x * self.y * self.z * self.threads
    }
}

impl GPUComputer {
    pub fn new(context: Context) -> Self {
        Self { context }
    }

    fn update_offset(&self, new_offset: u32) {
        self.context.wgpu_context.queue.write_buffer(
            &self.context.buffers.offset,
            0,
            bytemuck::bytes_of(&new_offset),
        );
    }

    fn setup_bind_group(&self) -> BindGroup {
        self.context.wgpu_context.create_bind_group(
            "bind group",
            &self.context.layouts.bind_group_layout,
            &[
                WGPUContext::create_bind_group_entry(0, &self.context.buffers.output),
                WGPUContext::create_bind_group_entry(1, &self.context.buffers.prefix),
                WGPUContext::create_bind_group_entry(2, &self.context.buffers.target),
                WGPUContext::create_bind_group_entry(3, &self.context.buffers.offset),
            ],
        )
    }

    fn create_encoder(&self) -> CommandEncoder {
        self.context
            .wgpu_context
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("Command Encoder"),
            })
    }

    fn setup_compute_pass(&self, workgroups: Workgroups, encoder: &mut CommandEncoder) {
        let mut compute_pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
            label: Some("Compute Pass"),
            timestamp_writes: None,
        });

        compute_pass.set_pipeline(&self.context.pipeline);
        compute_pass.set_bind_group(0, &self.setup_bind_group(), &[]);
        compute_pass.dispatch_workgroups(workgroups.x, workgroups.y, workgroups.z);
    }

    fn setup_output_staging(&self, encoder: &mut CommandEncoder) {
        encoder.copy_buffer_to_buffer(
            &self.context.buffers.output,
            0,
            &self.context.buffers.output_staging,
            0,
            self.context.buffers.output.size(),
        );
    }

    async fn read_output(&self) -> Vec<u32> {
        let slice = self.context.buffers.output_staging.slice(..);

        let (sen, rev) = futures_intrusive::channel::shared::oneshot_channel();

        slice.map_async(wgpu::MapMode::Read, move |v| sen.send(v).unwrap());
        self.context.wgpu_context.device.poll(wgpu::Maintain::Wait);
        #[allow(unused_must_use)]
        rev.receive().await.unwrap();

        let result = slice
            .get_mapped_range()
            .chunks(4)
            .map(|c| u32::from_le_bytes(c.try_into().unwrap()))
            .collect();

        self.context.buffers.output_staging.unmap();

        result
    }

    pub fn submit(&self, encoder: CommandEncoder) {
        self.context
            .wgpu_context
            .queue
            .submit(Some(encoder.finish()));
    }

    fn normal_compute_pass(&self, workgroups: Workgroups, offset: u32) {
        self.update_offset(offset);

        let mut encoder = self.create_encoder();
        self.setup_compute_pass(workgroups, &mut encoder);
        self.submit(encoder);
    }

    async fn check_compute_pass(&self, workgroups: Workgroups, offset: u32) -> Vec<u32> {
        self.update_offset(offset);

        let mut encoder = self.create_encoder();
        self.setup_compute_pass(workgroups, &mut encoder);
        self.setup_output_staging(&mut encoder);

        self.submit(encoder);

        self.read_output().await
    }

    pub async fn dispatch(
        &self,
        workgroups: Workgroups,
        max_iterations: u32,
        check_every: u32,
    ) -> Vec<u32> {
        for i in 0..max_iterations {
            let n = i * workgroups.total();

            if i % check_every == 0 {
                let result = self.check_compute_pass(workgroups, n).await;

                if result[0] != 0 {
                    println!(
                        "total hashes computed {}",
                        format((i + 1) * workgroups.total())
                    );
                    return result;
                }
            } else {
                self.normal_compute_pass(workgroups, n);
            }
        }

        let n = max_iterations * workgroups.total();

        println!("total hashes computed {}", format(n));

        return self.check_compute_pass(workgroups, n).await;
    }
}
