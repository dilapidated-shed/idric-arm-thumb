module RendererPrimitives

%default total

||| Explicit unboxed renderer scalar used at the ARM ABI seam.
export
data Float32 : Type where [external]

||| Polar Complex64: two Float32 words, physically (magnitude, phase).
||| The magnitude is nonnegative for values produced by float32_to_complex64.
||| This type is currently internal to a numerical leaf and is not a C ABI type.
export
data Complex64 : Type where [external]

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


export %extern complex64_from_polar : Float32 -> Float32 -> Complex64
export %extern float32_to_complex64 : Float32 -> Complex64

export %extern complex64_magnitude : Complex64 -> Float32
export %extern complex64_phase : Complex64 -> Float32

export %extern complex64_multiply : Complex64 -> Complex64 -> Complex64
export %extern complex64_divide : Complex64 -> Complex64 -> Complex64
export %extern complex64_conjugate : Complex64 -> Complex64
