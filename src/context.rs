use gpu_compute::WGPUContext;
use wgpu::{BindGroupLayout, Buffer};

pub struct Context {
    pub buffers: ComputeBuffers,
    pub layouts: ComputeLayouts,
    pub pipeline: wgpu::ComputePipeline,
    pub wgpu_context: WGPUContext,
}

pub struct ComputeLayouts {
    pub bind_group_layout: BindGroupLayout,
}

pub struct ComputeBuffers {
    pub prefix: Buffer,
    pub target: Buffer,
    pub offset: Buffer,
    pub output: Buffer,
    pub output_staging: Buffer,
}

impl Context {
    pub async fn new(prefix: &[u8], target: &[u8]) -> Self {
        let context = WGPUContext::new().await;

        let prefix_buffer =
            context.create_buffer_init("prefix input", wgpu::BufferUsages::STORAGE, prefix);

        let target_buffer =
            context.create_buffer_init("target input", wgpu::BufferUsages::STORAGE, target);

        let offset_buffer = context.create_buffer_init(
            "offset input",
            wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
            bytemuck::bytes_of(&0),
        );

        let output_buffer = context.create_buffer(
            "output",
            wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_SRC,
            (std::mem::size_of::<u32>() * 8) as u64,
        );

        let output_staging_buffer = context.create_buffer(
            "staying output stage",
            wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            (std::mem::size_of::<u32>() * 8) as u64,
        );

        let shader = &context.create_shader(
            "compute shader",
            context.load_wgsl_file("./shaders/nonce-hash.wgsl".into()),
        );

        let bind_group_layout = context.create_bind_group_layout(
            "bind group",
            &[
                context.create_bind_layout_entry(0, context.create_binding_type_buffer(false)), // output
                context.create_bind_layout_entry(1, context.create_binding_type_buffer(true)), // prefix
                context.create_bind_layout_entry(2, context.create_binding_type_buffer(true)), // target
                context.create_bind_layout_entry(3, context.create_binding_type_buffer(true)), // ofset
            ],
        );

        let pipeline_layout =
            context.create_pipeline_layout("pipeline layout", &[&bind_group_layout]);

        let compute_pipeline =
            context.create_compute_pipeline("compute pipeline", &pipeline_layout, shader, "main");

        Self {
            pipeline: compute_pipeline,
            layouts: ComputeLayouts { bind_group_layout },
            buffers: ComputeBuffers {
                prefix: prefix_buffer,
                target: target_buffer,
                offset: offset_buffer,
                output: output_buffer,
                output_staging: output_staging_buffer,
            },
            wgpu_context: context,
        }
    }
}
