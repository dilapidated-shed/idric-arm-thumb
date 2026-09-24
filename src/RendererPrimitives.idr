module RendererPrimitives

import Prelude.Float16
import Prelude.LowPrecision

%default total

||| Explicit unboxed renderer scalar used at the ARM ABI seam.
export
data Float32 : Type where [external]

-- Float16, E4M3, E5M2, E3M2, and E5M3 are canonical Prelude types.
-- This module supplies target-specific conversion and arithmetic primitives;
-- it does not define a second backend-only family of source types.

||| Caller-owned contiguous Float32 memory. The backend assumes a non-null,
||| suitably aligned pointer and an in-bounds Int32 index at the FFI boundary.
export
data Float32Buffer : Type where [external]

export %extern float32_buffer_load : Float32Buffer -> Int32 -> Float32

export %extern float32_add : Float32 -> Float32 -> Float32
export %extern float32_subtract : Float32 -> Float32 -> Float32
export %extern float32_multiply : Float32 -> Float32 -> Float32
export %extern float32_divide : Float32 -> Float32 -> Float32

export %extern float32_negate : Float32 -> Float32
export %extern float32_absolute : Float32 -> Float32
export %extern float32_square_root : Float32 -> Float32


-- Narrow scalar conversion boundary. Signed OCP formats use the saturating
-- conversion mode when converting Float32 back to the narrow format.
export %extern float16_to_float32 : Float16 -> Float32
export %extern float32_to_float16 : Float32 -> Float16
export %extern e4m3_to_float32 : E4M3 -> Float32
export %extern float32_to_e4m3 : Float32 -> E4M3
export %extern e5m2_to_float32 : E5M2 -> Float32
export %extern float32_to_e5m2 : Float32 -> E5M2
export %extern e3m2_to_float32 : E3M2 -> Float32
export %extern float32_to_e3m2 : Float32 -> E3M2
export %extern e5m3_to_float32 : E5M3 -> Float32
export %extern float32_to_e5m3 : Float32 -> E5M3

-- Arithmetic on Float16/E4M3/E5M2/E3M2 is explicitly widen-to-Float32,
-- compute once in Float32, then round back to the destination format.
-- E5M3 is a storage format in its source paper, so no arithmetic is invented.
export %extern float16_add : Float16 -> Float16 -> Float16
export %extern float16_subtract : Float16 -> Float16 -> Float16
export %extern float16_multiply : Float16 -> Float16 -> Float16
export %extern float16_divide : Float16 -> Float16 -> Float16

export %extern e4m3_add : E4M3 -> E4M3 -> E4M3
export %extern e4m3_subtract : E4M3 -> E4M3 -> E4M3
export %extern e4m3_multiply : E4M3 -> E4M3 -> E4M3
export %extern e4m3_divide : E4M3 -> E4M3 -> E4M3

export %extern e5m2_add : E5M2 -> E5M2 -> E5M2
export %extern e5m2_subtract : E5M2 -> E5M2 -> E5M2
export %extern e5m2_multiply : E5M2 -> E5M2 -> E5M2
export %extern e5m2_divide : E5M2 -> E5M2 -> E5M2

export %extern e3m2_add : E3M2 -> E3M2 -> E3M2
export %extern e3m2_subtract : E3M2 -> E3M2 -> E3M2
export %extern e3m2_multiply : E3M2 -> E3M2 -> E3M2
export %extern e3m2_divide : E3M2 -> E3M2 -> E3M2
