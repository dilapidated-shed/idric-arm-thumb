module Backend.ARMThumb.IR

import Data.String

%default total

||| Unboxed one-word representations admitted by the direct ARM boundary.
public export
data Representation
  = Word32
  | Bits8Value
  | Float16Value
  | E4M3Value
  | E5M2Value
  | E3M2Value
  | E5M3Value
  | Float32
  | Float32Pointer

public export
Eq Representation where
  Word32 == Word32 = True
  Bits8Value == Bits8Value = True
  Float16Value == Float16Value = True
  E4M3Value == E4M3Value = True
  E5M2Value == E5M2Value = True
  E3M2Value == E3M2Value = True
  E5M3Value == E5M3Value = True
  Float32 == Float32 = True
  Float32Pointer == Float32Pointer = True
  _ == _ = False

public export
Show Representation where
  show Word32 = "Word32"
  show Bits8Value = "Bits8"
  show Float16Value = "Float16"
  show E4M3Value = "E4M3"
  show E5M2Value = "E5M2"
  show E3M2Value = "E3M2"
  show E5M3Value = "E5M3"
  show Float32 = "Float32"
  show Float32Pointer = "Float32Pointer"

public export
data NarrowFloatFormat
  = Binary16
  | FP8E4M3
  | FP8E5M2
  | FP6E3M2
  | OotomoE5M3

public export
Eq NarrowFloatFormat where
  Binary16 == Binary16 = True
  FP8E4M3 == FP8E4M3 = True
  FP8E5M2 == FP8E5M2 = True
  FP6E3M2 == FP6E3M2 = True
  OotomoE5M3 == OotomoE5M3 = True
  _ == _ = False

public export
Show NarrowFloatFormat where
  show Binary16 = "Float16"
  show FP8E4M3 = "E4M3"
  show FP8E5M2 = "E5M2"
  show FP6E3M2 = "E3M2"
  show OotomoE5M3 = "E5M3"

public export
format_representation : NarrowFloatFormat -> Representation
format_representation Binary16 = Float16Value
format_representation FP8E4M3 = E4M3Value
format_representation FP8E5M2 = E5M2Value
format_representation FP6E3M2 = E3M2Value
format_representation OotomoE5M3 = E5M3Value

public export
data NarrowBinaryOperation
  = AddNarrow
  | SubtractNarrow
  | MultiplyNarrow
  | DivideNarrow

public export
Show NarrowBinaryOperation where
  show AddNarrow = "add"
  show SubtractNarrow = "subtract"
  show MultiplyNarrow = "multiply"
  show DivideNarrow = "divide"

public export
data Bits8BinaryOperation
  = AddBits8
  | SubtractBits8
  | MultiplyBits8

public export
Show Bits8BinaryOperation where
  show AddBits8 = "add"
  show SubtractBits8 = "subtract"
  show MultiplyBits8 = "multiply"

||| A validated ANF local and its dense four-byte stack home.
public export
record Local where
  constructor MkLocal
  anf_variable : Int
  frame_slot : Int
  representation : Representation

public export
Show Local where
  show local =
    "v" ++ show local.anf_variable ++
    ":" ++ show local.representation ++
    "@" ++ show local.frame_slot

public export
data FloatBinaryOperation
  = AddFloat32
  | SubtractFloat32
  | MultiplyFloat32
  | DivideFloat32

public export
Show FloatBinaryOperation where
  show AddFloat32 = "add"
  show SubtractFloat32 = "subtract"
  show MultiplyFloat32 = "multiply"
  show DivideFloat32 = "divide"

public export
data FloatUnaryOperation
  = NegateFloat32
  | AbsoluteFloat32
  | SquareRootFloat32

public export
Show FloatUnaryOperation where
  show NegateFloat32 = "negate"
  show AbsoluteFloat32 = "absolute"
  show SquareRootFloat32 = "square-root"

||| Validated runtime-free straight-line IR. Each instruction fixes the
||| representation required of its operands before assembly emission.
public export
data Instruction
  = Copy Local Local
  | WordConstant Local Int
  | Bits8Constant Local Int
  | LoadFloat32 Local Local Local
  | FloatBinary FloatBinaryOperation Local Local Local
  | FloatUnary FloatUnaryOperation Local Local
  | NarrowToFloat32 NarrowFloatFormat Local Local
  | Float32ToNarrow NarrowFloatFormat Local Local
  | NarrowBinary NarrowFloatFormat NarrowBinaryOperation Local Local Local
  | Bits8Binary Bits8BinaryOperation Local Local Local

public export
Show Instruction where
  show (Copy destination source) =
    show destination ++ " = copy " ++ show source
  show (WordConstant destination value) =
    show destination ++ " = word " ++ show value
  show (Bits8Constant destination value) =
    show destination ++ " = bits8 " ++ show value
  show (LoadFloat32 destination buffer index) =
    show destination ++ " = load " ++ show buffer ++ "[" ++ show index ++ "]"
  show (FloatBinary operation destination left right) =
    show destination ++ " = " ++ show operation ++
    " " ++ show left ++ " " ++ show right
  show (FloatUnary operation destination value) =
    show destination ++ " = " ++ show operation ++ " " ++ show value
  show (NarrowToFloat32 format destination value) =
    show destination ++ " = " ++ show format ++ "->Float32 " ++ show value
  show (Float32ToNarrow format destination value) =
    show destination ++ " = Float32->" ++ show format ++ " " ++ show value
  show (NarrowBinary format operation destination left right) =
    show destination ++ " = " ++ show format ++ "." ++ show operation ++
    " " ++ show left ++ " " ++ show right
  show (Bits8Binary operation destination left right) =
    show destination ++ " = Bits8." ++ show operation ++
    " " ++ show left ++ " " ++ show right

||| One C-callable, closure-free numerical leaf.
public export
record LeafFunction where
  constructor MkLeafFunction
  external_symbol : String
  arguments : List Local
  instructions : List Instruction
  result : Local
  frame_bytes : Int

public export
render_ir : LeafFunction -> String
render_ir function =
  unlines
    ([ "function " ++ function.external_symbol
     , "arguments: " ++ show function.arguments
     ] ++
     map (\instruction => "  " ++ show instruction) function.instructions ++
     [ "return " ++ show function.result
     , "frame-bytes: " ++ show function.frame_bytes
     ])
