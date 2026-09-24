module Backend.ARMThumb.Emit

import Backend.ARMThumb.IR
import Backend.ARMThumb.Lower
import Backend.ARMThumb.Scalar
import Data.String

%default total

private
slot_address : Local -> String
slot_address local =
  "[sp, #" ++ show (local.frame_slot * 4) ++ "]"

private
load_word : String -> Local -> List String
load_word register local =
  ["        ldr     " ++ register ++ ", " ++ slot_address local]

private
store_word : String -> Local -> List String
store_word register local =
  ["        str     " ++ register ++ ", " ++ slot_address local]

private
load_float : String -> Local -> List String
load_float register local =
  ["        vldr    " ++ register ++ ", " ++ slot_address local]

private
store_float : String -> Local -> List String
store_float register local =
  ["        vstr    " ++ register ++ ", " ++ slot_address local]

private
materialise_word32 : Int -> List String
materialise_word32 value =
  let unsigned_value = if value < 0 then value + 4294967296 else value
      low_half = unsigned_value `mod` 65536
      high_half = unsigned_value `div` 65536
  in
    [ "        movw    r0, #" ++ show low_half
    , "        movt    r0, #" ++ show high_half
    ]

private
float_binary_mnemonic : FloatBinaryOperation -> String
float_binary_mnemonic AddFloat32 = "vadd.f32"
float_binary_mnemonic SubtractFloat32 = "vsub.f32"
float_binary_mnemonic MultiplyFloat32 = "vmul.f32"
float_binary_mnemonic DivideFloat32 = "vdiv.f32"

private
float_unary_mnemonic : FloatUnaryOperation -> String
float_unary_mnemonic NegateFloat32 = "vneg.f32"
float_unary_mnemonic AbsoluteFloat32 = "vabs.f32"
float_unary_mnemonic SquareRootFloat32 = "vsqrt.f32"

private
narrow_binary_mnemonic : NarrowBinaryOperation -> String
narrow_binary_mnemonic AddNarrow = "vadd.f32"
narrow_binary_mnemonic SubtractNarrow = "vsub.f32"
narrow_binary_mnemonic MultiplyNarrow = "vmul.f32"
narrow_binary_mnemonic DivideNarrow = "vdiv.f32"

private
bits8_binary_lines : Bits8BinaryOperation -> List String
bits8_binary_lines AddBits8 =
  [ "        add.w   r0, r0, r1"
  , "        uxtb    r0, r0"
  ]
bits8_binary_lines SubtractBits8 =
  [ "        sub.w   r0, r0, r1"
  , "        uxtb    r0, r0"
  ]
bits8_binary_lines MultiplyBits8 =
  [ "        mul     r0, r0, r1"
  , "        uxtb    r0, r0"
  ]

private
emit_instruction : Instruction -> List String
emit_instruction (Copy destination source) =
  load_word "r0" source ++ store_word "r0" destination
emit_instruction (WordConstant destination value) =
  materialise_word32 value ++ store_word "r0" destination
emit_instruction (Bits8Constant destination value) =
  [ "        movs    r0, #" ++ show value ] ++ store_word "r0" destination
emit_instruction (LoadFloat32 destination buffer index) =
  load_word "r0" buffer ++
  load_word "r1" index ++
  [ "        add.w   r0, r0, r1, lsl #2"
  , "        vldr    s0, [r0]"
  ] ++
  store_float "s0" destination
emit_instruction (FloatBinary operation destination left right) =
  load_float "s0" left ++
  load_float "s1" right ++
  [ "        " ++ float_binary_mnemonic operation ++ " s0, s0, s1" ] ++
  store_float "s0" destination
emit_instruction (FloatUnary operation destination value) =
  load_float "s0" value ++
  [ "        " ++ float_unary_mnemonic operation ++ " s0, s0" ] ++
  store_float "s0" destination
emit_instruction (NarrowToFloat32 format destination value) =
  load_word "r0" value ++
  [ "        bl      " ++ to_float32_helper format ] ++
  store_word "r0" destination
emit_instruction (Float32ToNarrow format destination value) =
  load_word "r0" value ++
  [ "        bl      " ++ from_float32_helper format ] ++
  store_word "r0" destination
emit_instruction (NarrowBinary format operation destination left right) =
  load_word "r0" left ++
  [ "        bl      " ++ to_float32_helper format
  , "        vmov    s0, r0"
  ] ++
  load_word "r0" right ++
  [ "        bl      " ++ to_float32_helper format
  , "        vmov    s1, r0"
  , "        " ++ narrow_binary_mnemonic operation ++ " s0, s0, s1"
  , "        vmov    r0, s0"
  , "        bl      " ++ from_float32_helper format
  ] ++
  store_word "r0" destination
emit_instruction (Bits8Binary operation destination left right) =
  load_word "r0" left ++
  load_word "r1" right ++
  bits8_binary_lines operation ++
  store_word "r0" destination

private
emit_instructions : List Instruction -> List String
emit_instructions [] = []
emit_instructions (instruction :: rest) =
  emit_instruction instruction ++ emit_instructions rest

private
argument_registers : List String
argument_registers = ["r0", "r1", "r2", "r3"]

private
store_arguments : List Local -> List String -> List String
store_arguments [] registers = []
store_arguments (argument :: rest) (register :: registers) =
  store_word register argument ++ store_arguments rest registers
store_arguments arguments [] = []

private
expect_representation : String -> Representation -> Local -> Either String ()
expect_representation role expected local =
  if local.representation == expected
    then Right ()
    else Left (role ++ " expected " ++ show expected ++ ", but got " ++ show local)

private
validate_local_home : LeafFunction -> Local -> Either String ()
validate_local_home function local =
  if local.frame_slot < 0 || local.frame_slot * 4 + 4 > function.frame_bytes
    then
      Left
        ("Local " ++ show local ++ " is outside the " ++
         show function.frame_bytes ++ "-byte frame")
    else Right ()

private
validate_instruction : LeafFunction -> Instruction -> Either String ()
validate_instruction function (Copy destination source) = do
  validate_local_home function destination
  validate_local_home function source
  if destination.representation == source.representation
    then Right ()
    else Left "Copy operands have different representations"
validate_instruction function (WordConstant destination value) = do
  validate_local_home function destination
  expect_representation "Word constant" Word32 destination
  if value >= -2147483648 && value <= 2147483647
    then Right ()
    else Left ("Word constant is outside signed Int32 range: " ++ show value)
validate_instruction function (Bits8Constant destination value) = do
  validate_local_home function destination
  expect_representation "Bits8 constant" Bits8Value destination
  if value >= 0 && value <= 255
    then Right ()
    else Left ("Bits8 constant is outside 0..255: " ++ show value)
validate_instruction function (LoadFloat32 destination buffer index) = do
  validate_local_home function destination
  validate_local_home function buffer
  validate_local_home function index
  expect_representation "Buffer load result" Float32 destination
  expect_representation "Buffer load pointer" Float32Pointer buffer
  expect_representation "Buffer load index" Word32 index
validate_instruction function (FloatBinary operation destination left right) = do
  validate_local_home function destination
  validate_local_home function left
  validate_local_home function right
  expect_representation "Float binary result" Float32 destination
  expect_representation "Float binary left operand" Float32 left
  expect_representation "Float binary right operand" Float32 right
validate_instruction function (FloatUnary operation destination value) = do
  validate_local_home function destination
  validate_local_home function value
  expect_representation "Float unary result" Float32 destination
  expect_representation "Float unary operand" Float32 value
validate_instruction function (NarrowToFloat32 format destination value) = do
  validate_local_home function destination
  validate_local_home function value
  expect_representation "Narrow conversion result" Float32 destination
  expect_representation "Narrow conversion operand"
    (format_representation format) value
validate_instruction function (Float32ToNarrow format destination value) = do
  validate_local_home function destination
  validate_local_home function value
  expect_representation "Narrow conversion result"
    (format_representation format) destination
  expect_representation "Narrow conversion operand" Float32 value
validate_instruction function (NarrowBinary format operation destination left right) = do
  validate_local_home function destination
  validate_local_home function left
  validate_local_home function right
  let representation = format_representation format
  expect_representation "Narrow binary result" representation destination
  expect_representation "Narrow binary left operand" representation left
  expect_representation "Narrow binary right operand" representation right
  if format == OotomoE5M3
    then Left "Ootomo-Naruse E5M3 defines storage conversion, not arithmetic"
    else Right ()
validate_instruction function (Bits8Binary operation destination left right) = do
  validate_local_home function destination
  validate_local_home function left
  validate_local_home function right
  expect_representation "Bits8 binary result" Bits8Value destination
  expect_representation "Bits8 binary left operand" Bits8Value left
  expect_representation "Bits8 binary right operand" Bits8Value right

private
validate_instructions : LeafFunction -> List Instruction -> Either String ()
validate_instructions function [] = Right ()
validate_instructions function (instruction :: rest) = do
  validate_instruction function instruction
  validate_instructions function rest

private
validate_arguments : LeafFunction -> List Local -> Either String ()
validate_arguments function [] = Right ()
validate_arguments function (argument :: rest) = do
  validate_local_home function argument
  validate_arguments function rest

private
is_scalar_result : Representation -> Bool
is_scalar_result Float32 = True
is_scalar_result Bits8Value = True
is_scalar_result Float16Value = True
is_scalar_result E4M3Value = True
is_scalar_result E5M2Value = True
is_scalar_result E3M2Value = True
is_scalar_result E5M3Value = True
is_scalar_result _ = False

private
validate_leaf_for_emission : LeafFunction -> Either String ()
validate_leaf_for_emission function = do
  _ <- validate_external_symbol function.external_symbol
  if function.frame_bytes <= 0 ||
     function.frame_bytes > 1024 ||
     function.frame_bytes `mod` 8 /= 0
    then
      Left
        ("ARM Thumb leaf frame must be 8-byte aligned and between 8 and " ++
         "1024 bytes, got " ++ show function.frame_bytes)
    else Right ()
  if length function.arguments > 4
    then Left "ARM Thumb softfp leaves admit at most four one-word arguments"
    else Right ()
  validate_arguments function function.arguments
  validate_instructions function function.instructions
  validate_local_home function function.result
  if is_scalar_result function.result.representation
    then Right ()
    else Left ("Function result is not a supported scalar: " ++ show function.result)

||| Emit Android armeabi-v7a Thumb-2. Arguments cross the softfp C ABI as
||| raw one-word values in r0-r3; VFPv3-D16 is used inside numerical leaves.
public export
emit_leaf : LeafFunction -> Either String String
emit_leaf function = do
  validate_leaf_for_emission function
  Right (unlines
    ([ ""
     , "        .p2align 2"
     , "        .global " ++ function.external_symbol
     , "        .type " ++ function.external_symbol ++ ", %function"
     , "        .thumb_func"
     , function.external_symbol ++ ":"
     , "        push    {r4, lr}"
     , "        sub.w   sp, sp, #" ++ show function.frame_bytes
     ] ++
     store_arguments function.arguments argument_registers ++
     emit_instructions function.instructions ++
     load_word "r0" function.result ++
     [ "        add.w   sp, sp, #" ++ show function.frame_bytes
     , "        pop     {r4, pc}"
     , "        .size " ++ function.external_symbol ++ ", .-" ++ function.external_symbol
     ]))

public export
assembly_header : String
assembly_header =
  unlines
    [ ".syntax unified"
    , ".arch armv7-a"
    , ".fpu vfpv3-d16"
    , ".thumb"
    , ".text"
    , ""
    , "@ Runtime-free Idriç numerical leaves for Android armeabi-v7a."
    , "@ C ABI: softfp at the boundary, hardware Float32 internally."
    ]

public export
assembly_footer : String
assembly_footer =
  scalar_helpers ++ "\n.section .note.GNU-stack,\"\",%progbits\n"
