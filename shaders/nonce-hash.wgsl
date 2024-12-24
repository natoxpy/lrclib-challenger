@group(0) @binding(0) var<storage, read_write> output : array<atomic<u32>>; //Output data
@group(0) @binding(1) var<storage, read> prefix : array<u32>; //Output data
@group(0) @binding(2) var<storage, read> target_data : array<u32>; //Output data
@group(0) @binding(3) var<storage, read> offset : array<u32>; //Output data

const block_x : u32 = 64u;
const block_y : u32 = 1u;
const block_z : u32 = 1u;

const h0 : array<u32, 8> = array<u32,8>(0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19);
const k : array<u32, 64> = array<u32,64>(0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2);

const numThreadsPerWorkgroup = block_x * block_y * block_z;

fn reverse_number(num: u32) -> u32 {
    var reversed: u32 = 0u;
    var value: u32 = num;

    while value > 0u {
        reversed = reversed * 10u + (value % 10u);
        value = value / 10u;
    }

    return reversed;
}

fn count_digits(num: u32) -> u32 {
    var value: u32 = num;
    var digit_count: u32 = 0u;

    // If the number is 0, it has 1 digit
    if value == 0u {
        return 1u;
    }

    // Count the digits by repeatedly dividing by 10
    while value > 0u {
        value = value / 10u;
        digit_count = digit_count + 1u;
    }

    return digit_count;
}

fn n(num: u32, digit: u32) -> u32 {
    var value: u32 = reverse_number(num);

    // Divide the number by 10^(digit) to shift the desired digit to the least significant place
    for (var i: u32 = 0u; i < digit; i = i + 1u) {
        value = value / 10u;
    }

    // Return the last digit (value % 10)
    return value % 10u;
}

fn arr_get(r: array<u32, 3>, i: u32) -> u32 {
    return (r[i / 4] >> (3 - (i % 4))) & 0xff;
}

fn arr_set(r: array<u32, 3>, idx: u32, value: u32) -> array<u32,3> {
    var rl = r;
    let aid = idx / 4u;
    let iid = (3 - (idx % 4)) * 8;
    let rli = rl[aid];
    rl[aid] = (rli & ~(u32(0xff) << iid)) | (value << iid);

    return rl;
}

fn num_to_utf8(num: u32) -> array<u32, 3> {
    let i1_1 = 48 + n(num, 0u);
    let i1_2 = 48 + n(num, 1u);
    let i1_3 = 48 + n(num, 2u);
    let i1_4 = 48 + n(num, 3u);

    let i2_1 = 48 + n(num, 4u);
    let i2_2 = 48 + n(num, 5u);
    let i2_3 = 48 + n(num, 6u);
    let i2_4 = 48 + n(num, 7u);

    let i3_1 = 48 + n(num, 8u);
    let i3_2 = 48 + n(num, 9u);
    let i3_3 = 48 + n(num, 10u);
    let i3_4 = 48 + n(num, 11u);

    var r = array<u32,3>();
    let l = count_digits(num);

    if l > 0 {
        r = arr_set(r, 3u, i1_1);
    }
    if l > 1 {
        r = arr_set(r, 2u, i1_2);
    }
    if l > 2 {
        r = arr_set(r, 1u, i1_3);
    }
    if l > 3 {
        r = arr_set(r, 0u, i1_4);
    }


    if l > 4 {
        r = arr_set(r, 7u, i2_1);
    }

    if l > 5 {
        r = arr_set(r, 6u, i2_2);
    }

    if l > 6 {
        r = arr_set(r, 5u, i2_3);
    }

    if l > 7 {
        r = arr_set(r, 4u, i2_4);
    }


    if l > 8 {
        r = arr_set(r, 11u, i3_1);
    }

    if l > 9 {
        r = arr_set(r, 10u, i3_2);
    }

    if l > 10 {
        r = arr_set(r, 9u, i3_3);
    }

    if l > 11 {
        r = arr_set(r, 8u, i3_4);
    }


    return r;
}

fn preprocess(msg: array<u32, 3>, msg_context: u32) -> array<u32,16> {
    var m = array<u32, 16>();

    for (var i = 0u; i < 8u; i++) {
        m[i] = prefix[i];
    }

    let digits = count_digits(msg_context);

    if digits >= 0 && digits < 4 {
        m[8] = msg[0] | 0x80u << (8u * digits);
    } else {
        m[8] = msg[0];
    }


    if digits >= 4 && digits < 8 {
        m[9] = msg[1] | 0x80u << (8u * (digits - 4));
    } else {
        m[9] = msg[1];
    }

    if digits >= 8 && digits < 12 {
        m[10] = msg[2] | 0x80u << (8u * (digits - 8));
    } else {
        m[10] = msg[2];
    }


    if digits >= 12 {
        m[11] = 0x80u;
    }

    m[15] = 1u << 16u | (8u * digits) << 24u;

    return m;
}

fn rotr(x: u32, n: u32) -> u32 {
    return (x >> n) | x << (32u - n);
}

fn add(a: u32, b: u32) -> u32 {
    return a + b;
}

fn choice(x: u32, y: u32, z: u32) -> u32 {
    return (x & y) ^ (~x & z);
}

fn majority(x: u32, y: u32, z: u32) -> u32 {
    return (x & y) ^ (x & z) ^ (y & z);
}

fn big_sigma_0(x: u32) -> u32 {
    return rotr(x, 2u) ^ rotr(x, 13u) ^ rotr(x, 22u);
}

fn big_sigma_1(x: u32) -> u32 {
    return rotr(x, 6u) ^ rotr(x, 11u) ^ rotr(x, 25u);
}

fn sigma_0(x: u32) -> u32 {
    return rotr(x, 7u) ^ rotr(x, 18u) ^ (x >> 3u);
}

fn sigma_1(x: u32) -> u32 {
    return rotr(x, 17u) ^ rotr(x, 19u) ^ (x >> 10u);
}

fn reverse_u32_bytes(value: u32) -> u32 {
    let byte0 = (value & 0x000000FFu) << 24u;
    let byte1 = (value & 0x0000FF00u) << 8u;
    let byte2 = (value & 0x00FF0000u) >> 8u;
    let byte3 = (value & 0xFF000000u) >> 24u;
    return byte0 | byte1 | byte2 | byte3;
}

fn schedule_message(m: array<u32, 16>) -> array<u32, 64> {
    var w = array<u32,64>();

    for (var i = 0; i < 16; i++) {
        w[i] = reverse_u32_bytes(m[i]);
    }

    for (var i = 16; i < 64; i++) {
        w[i] = add(
            add(sigma_0(w[i - 15]), w[i - 7]),
            add(sigma_1(w[i - 2]), w[i - 16])
        );
    }

    return w;
}

fn digest(w: array<u32,64>) -> array<u32, 8> {

    var a = h0[0];
    var b = h0[1];
    var c = h0[2];
    var d = h0[3];
    var e = h0[4];
    var f = h0[5];
    var g = h0[6];
    var h = h0[7];

    for (var i = 0; i < 64; i++) {
        let t1 = h + big_sigma_1(e) + choice(e, f, g) + k[i] + w[i];
        let t2 = big_sigma_0(a) + majority(a, b, c);
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }

    a = a + h0[0];
    b = b + h0[1];
    c = c + h0[2];
    d = d + h0[3];
    e = e + h0[4];
    f = f + h0[5];
    g = g + h0[6];
    h = h + h0[7];

    return array<u32,8>(a, b, c, d, e, f, g, h);
}

// PROOF OF WORK

//little indian to big indian
fn le_to_be(value: u32) -> u32 {
    let byte0 = value & 0xFF;
    let byte1 = (value >> 8) & 0xFF;
    let byte2 = (value >> 16) & 0xFF;
    let byte3 = (value >> 24) & 0xFF;

    return byte0 << 24 | byte1 << 16 | byte2 << 8 | byte3;
}

//check if hash < target
fn validate(data: array<u32, 8>) -> bool {

    for (var i = 0u; i < 8; i++) {
        let tar = le_to_be(target_data[i]);
        var dat = data[i];

        if dat > tar {
            return false;
        } else if dat < tar {
            return true;
        } else {
            break;
        }
    }

    return true;
}

@compute @workgroup_size(block_x, block_y, block_z)
fn main(
    @builtin(local_invocation_index) local_invocation_index: u32, @builtin(workgroup_id) workgroup_id: vec3<u32>,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
) {
    let total_workgroups = num_workgroups.x * num_workgroups.y * num_workgroups.z;
    let workgroup_index = workgroup_id.x + workgroup_id.y * num_workgroups.x + workgroup_id.z * num_workgroups.x * num_workgroups.y;
    let index = workgroup_index * numThreadsPerWorkgroup + local_invocation_index;

    let start = offset[0];

    let value = start + u32(index);

    let input = num_to_utf8(value);
    let pa = preprocess(input, value);
    let sc = schedule_message(pa);
    let hash = digest(sc);

    if validate(hash) {
        if atomicLoad(&output[0]) == 0 {
            output[atomicLoad(&output[0]) + 1] = value;
        }

        atomicAdd(&output[0], 1u);
    }
}
