module Backend.ARMThumb.Lower

import Backend.ARMThumb.IR
import Compiler.ANF
import Core.Name
import Core.Name.Namespace
import Core.TT.Primitive

%default covering

private
max_locals : Int
max_locals = 256

private
data RepresentationConstraint
  = HasRepresentation Int Representation
  | SameRepresentation Int Int

private
data RawInstruction
  = RawCopy Int Int
  | RawWordConstant Int Int
  | RawLoadFloat32 Int Int Int
  | RawFloatBinary FloatBinaryOperation Int Int Int
  | RawFloatUnary FloatUnaryOperation Int Int
  | RawMakeComplex64 Int Int Int
  | RawRealToComplex64 Int Int
  | RawComplexMagnitude Int Int
  | RawComplexPhase Int Int
  | RawComplexBinary ComplexBinaryOperation Int Int Int
  | RawComplexConjugate Int Int

private
record BuildState where
  constructor MkBuildState
  bound_variables : List Int
  raw_instructions_reversed : List RawInstruction
  constraints : List RepresentationConstraint

private
empty_state : BuildState
empty_state = MkBuildState [] [] []

private
is_ascii_letter : Char -> Bool
is_ascii_letter character =
  (character >= 'A' && character <= 'Z') ||
  (character >= 'a' && character <= 'z')

private
is_ascii_digit : Char -> Bool
is_ascii_digit character =
  character >= '0' && character <= '9'

private
is_symbol_start : Char -> Bool
is_symbol_start character =
  is_ascii_letter character || character == '_'

private
is_symbol_rest : Char -> Bool
is_symbol_rest character =
  is_symbol_start character || is_ascii_digit character

public export
validate_external_symbol : String -> Either String String
validate_external_symbol symbol =
  case unpack symbol of
    [] => Left "An exported ARM symbol cannot be empty"
    first :: rest =>
      if is_symbol_start first && all is_symbol_rest rest
        then Right symbol
        else Left ("Invalid C-compatible ARM symbol `" ++ symbol ++ "`")

private
renderer_name : String -> Name
renderer_name leaf =
  NS (mkNamespace "RendererPrimitives") (UN (Basic leaf))

private
data RendererPrimitive
  = BufferLoad
  | Binary FloatBinaryOperation
  | Unary FloatUnaryOperation
  | ComplexFromPolar
  | RealToComplex
  | ComplexMagnitudePrimitive
  | ComplexPhasePrimitive
  | ComplexBinaryPrimitive ComplexBinaryOperation
  | ComplexConjugatePrimitive

private
renderer_primitive : Name -> Maybe RendererPrimitive
renderer_primitive name =
  if name == renderer_name "float32_buffer_load"
    then Just BufferLoad
    else if name == renderer_name "float32_add"
      then Just (Binary AddFloat32)
      else if name == renderer_name "float32_subtract"
        then Just (Binary SubtractFloat32)
        else if name == renderer_name "float32_multiply"
          then Just (Binary MultiplyFloat32)
          else if name == renderer_name "float32_divide"
            then Just (Binary DivideFloat32)
            else if name == renderer_name "float32_negate"
              then Just (Unary NegateFloat32)
              else if name == renderer_name "float32_absolute"
                then Just (Unary AbsoluteFloat32)
                else if name == renderer_name "float32_square_root"
                  then Just (Unary SquareRootFloat32)
                  else if name == renderer_name "complex64_from_polar"
                    then Just ComplexFromPolar
                    else if name == renderer_name "float32_to_complex64"
                      then Just RealToComplex
                      else if name == renderer_name "complex64_magnitude"
                        then Just ComplexMagnitudePrimitive
                        else if name == renderer_name "complex64_phase"
                          then Just ComplexPhasePrimitive
                          else if name == renderer_name "complex64_multiply"
                            then Just (ComplexBinaryPrimitive MultiplyComplex64)
                            else if name == renderer_name "complex64_divide"
                              then Just (ComplexBinaryPrimitive DivideComplex64)
                              else if name == renderer_name "complex64_conjugate"
                                then Just ComplexConjugatePrimitive
                                else Nothing

private
add_constraint : RepresentationConstraint -> BuildState -> BuildState
add_constraint constraint
               (MkBuildState bound instructions constraints) =
  MkBuildState bound instructions (constraint :: constraints)

private
add_instruction : RawInstruction -> BuildState -> BuildState
add_instruction instruction
                (MkBuildState bound instructions constraints) =
  MkBuildState bound (instruction :: instructions) constraints

private
bind_variable : String -> Int -> BuildState -> Either String BuildState
bind_variable role variable
              (MkBuildState bound instructions constraints) =
  if elem variable bound
    then
      Left
        (role ++ " v" ++ show variable ++
         " is already defined in this numerical leaf")
    else if cast (length bound) >= max_locals
      then
        Left
          ("The numerical leaf needs more than " ++ show max_locals ++
           " locals")
      else
        Right
          (MkBuildState
            (variable :: bound)
            instructions
            constraints)

private
require_bound : String -> Int -> BuildState -> Either String ()
require_bound role variable state =
  if elem variable state.bound_variables
    then Right ()
    else Left (role ++ " reads unbound ANF local v" ++ show variable)

private
bind_arguments :
  List Int ->
  List Representation ->
  BuildState ->
  Either String BuildState
bind_arguments [] [] state = Right state
bind_arguments (argument :: rest) (representation :: representations) state = do
  with_argument <- bind_variable "Argument" argument state
  bind_arguments
    rest
    representations
    (add_constraint (HasRepresentation argument representation) with_argument)
bind_arguments variables representations state =
  Left
    ("Source ABI describes " ++ show (length representations) ++
     " arguments, but ANF contains " ++ show (length variables))

private
add_copy : Int -> Int -> BuildState -> BuildState
add_copy destination source state =
  add_instruction (RawCopy destination source)
    (add_constraint (SameRepresentation destination source) state)

private
add_word_constant : Int -> Int -> BuildState -> BuildState
add_word_constant destination value state =
  add_instruction (RawWordConstant destination value)
    (add_constraint (HasRepresentation destination Word32) state)

private
add_buffer_load : Int -> Int -> Int -> BuildState -> BuildState
add_buffer_load destination buffer index state =
  add_instruction (RawLoadFloat32 destination buffer index)
    (add_constraint (HasRepresentation destination Float32)
      (add_constraint (HasRepresentation buffer Float32Pointer)
        (add_constraint (HasRepresentation index Word32) state)))

private
add_float_binary :
  FloatBinaryOperation -> Int -> Int -> Int -> BuildState -> BuildState
add_float_binary operation destination left right state =
  add_instruction (RawFloatBinary operation destination left right)
    (add_constraint (HasRepresentation destination Float32)
      (add_constraint (HasRepresentation left Float32)
        (add_constraint (HasRepresentation right Float32) state)))

private
add_float_unary :
  FloatUnaryOperation -> Int -> Int -> BuildState -> BuildState
add_float_unary operation destination value state =
  add_instruction (RawFloatUnary operation destination value)
    (add_constraint (HasRepresentation destination Float32)
      (add_constraint (HasRepresentation value Float32) state))

private
add_make_complex64 : Int -> Int -> Int -> BuildState -> BuildState
add_make_complex64 destination magnitude phase state =
  add_instruction (RawMakeComplex64 destination magnitude phase)
    (add_constraint (HasRepresentation destination Complex64)
      (add_constraint (HasRepresentation magnitude Float32)
        (add_constraint (HasRepresentation phase Float32) state)))

private
add_real_to_complex64 : Int -> Int -> BuildState -> BuildState
add_real_to_complex64 destination value state =
  add_instruction (RawRealToComplex64 destination value)
    (add_constraint (HasRepresentation destination Complex64)
      (add_constraint (HasRepresentation value Float32) state))

private
add_complex_magnitude : Int -> Int -> BuildState -> BuildState
add_complex_magnitude destination value state =
  add_instruction (RawComplexMagnitude destination value)
    (add_constraint (HasRepresentation destination Float32)
      (add_constraint (HasRepresentation value Complex64) state))

private
add_complex_phase : Int -> Int -> BuildState -> BuildState
add_complex_phase destination value state =
  add_instruction (RawComplexPhase destination value)
    (add_constraint (HasRepresentation destination Float32)
      (add_constraint (HasRepresentation value Complex64) state))

private
add_complex_binary :
  ComplexBinaryOperation -> Int -> Int -> Int -> BuildState -> BuildState
add_complex_binary operation destination left right state =
  add_instruction (RawComplexBinary operation destination left right)
    (add_constraint (HasRepresentation destination Complex64)
      (add_constraint (HasRepresentation left Complex64)
        (add_constraint (HasRepresentation right Complex64) state)))

private
add_complex_conjugate : Int -> Int -> BuildState -> BuildState
add_complex_conjugate destination value state =
  add_instruction (RawComplexConjugate destination value)
    (add_constraint (HasRepresentation destination Complex64)
      (add_constraint (HasRepresentation value Complex64) state))

private
lower_external :
  Int -> Name -> List AVar -> BuildState -> Either String BuildState
lower_external destination name arguments state =
  case renderer_primitive name of
    Nothing =>
      Left
        ("Unsupported external primitive `" ++ show name ++
         "`; renderer intrinsics are matched by exact fully qualified name")
    Just BufferLoad =>
      case arguments of
        [ALocal buffer, ALocal index] => do
          require_bound "Float32 buffer load" buffer state
          require_bound "Float32 buffer index" index state
          with_destination <- bind_variable "Let destination" destination state
          Right (add_buffer_load destination buffer index with_destination)
        _ =>
          Left
            ("Renderer primitive `" ++ show name ++
             "` requires two local operands, got " ++ show arguments)
    Just (Binary operation) =>
      case arguments of
        [ALocal left, ALocal right] => do
          require_bound (show operation ++ " left operand") left state
          require_bound (show operation ++ " right operand") right state
          with_destination <- bind_variable "Let destination" destination state
          Right (add_float_binary operation destination left right with_destination)
        _ =>
          Left
            ("Renderer primitive `" ++ show name ++
             "` requires two local operands, got " ++ show arguments)
    Just (Unary operation) =>
      case arguments of
        [ALocal value] => do
          require_bound (show operation ++ " operand") value state
          with_destination <- bind_variable "Let destination" destination state
          Right (add_float_unary operation destination value with_destination)
        _ =>
          Left
            ("Renderer primitive `" ++ show name ++
             "` requires one local operand, got " ++ show arguments)
    Just ComplexFromPolar =>
      case arguments of
        [ALocal magnitude, ALocal phase] => do
          require_bound "Complex64 magnitude" magnitude state
          require_bound "Complex64 phase" phase state
          with_destination <- bind_variable "Let destination" destination state
          Right (add_make_complex64 destination magnitude phase with_destination)
        _ =>
          Left
            ("Renderer primitive `" ++ show name ++
             "` requires two local operands, got " ++ show arguments)
    Just RealToComplex =>
      case arguments of
        [ALocal value] => do
          require_bound "Float32 to Complex64 operand" value state
          with_destination <- bind_variable "Let destination" destination state
          Right (add_real_to_complex64 destination value with_destination)
        _ =>
          Left
            ("Renderer primitive `" ++ show name ++
             "` requires one local operand, got " ++ show arguments)
    Just ComplexMagnitudePrimitive =>
      case arguments of
        [ALocal value] => do
          require_bound "Complex64 magnitude operand" value state
          with_destination <- bind_variable "Let destination" destination state
          Right (add_complex_magnitude destination value with_destination)
        _ =>
          Left
            ("Renderer primitive `" ++ show name ++
             "` requires one local operand, got " ++ show arguments)
    Just ComplexPhasePrimitive =>
      case arguments of
        [ALocal value] => do
          require_bound "Complex64 phase operand" value state
          with_destination <- bind_variable "Let destination" destination state
          Right (add_complex_phase destination value with_destination)
        _ =>
          Left
            ("Renderer primitive `" ++ show name ++
             "` requires one local operand, got " ++ show arguments)
    Just (ComplexBinaryPrimitive operation) =>
      case arguments of
        [ALocal left, ALocal right] => do
          require_bound (show operation ++ " left operand") left state
          require_bound (show operation ++ " right operand") right state
          with_destination <- bind_variable "Let destination" destination state
          Right (add_complex_binary operation destination left right with_destination)
        _ =>
          Left
            ("Renderer primitive `" ++ show name ++
             "` requires two local operands, got " ++ show arguments)
    Just ComplexConjugatePrimitive =>
      case arguments of
        [ALocal value] => do
          require_bound "Complex64 conjugate operand" value state
          with_destination <- bind_variable "Let destination" destination state
          Right (add_complex_conjugate destination value with_destination)
        _ =>
          Left
            ("Renderer primitive `" ++ show name ++
             "` requires one local operand, got " ++ show arguments)

private
lower_value : Int -> ANF -> BuildState -> Either String BuildState
lower_value destination (AV _ (ALocal source)) state = do
  require_bound "Copy" source state
  with_destination <- bind_variable "Let destination" destination state
  Right (add_copy destination source with_destination)
lower_value destination (APrimVal _ (I32 value)) state = do
  with_destination <- bind_variable "Let destination" destination state
  Right (add_word_constant destination (cast value) with_destination)
lower_value destination (APrimVal _ (I value)) state =
  Left
    ("Idriç Int is 64-bit in the pinned compiler; use Int32 in this " ++
     "one-word ARMv7 ABI (got literal " ++ show value ++ ")")
lower_value destination (AExtPrim _ _ name arguments) state =
  lower_external destination name arguments state
lower_value destination expression state =
  Left
    ("Unsupported ANF value in the runtime-free numerical subset: " ++
     show expression)

private
lower_assignment : Int -> ANF -> BuildState -> Either String BuildState
lower_assignment destination (ALet _ nested_destination nested_value body) state = do
  after_nested <- lower_assignment nested_destination nested_value state
  lower_assignment destination body after_nested
lower_assignment destination value state = lower_value destination value state

private
fresh_variable_from : Int -> List Int -> Int
fresh_variable_from candidate used =
  if elem candidate used then fresh_variable_from (candidate + 1) used else candidate

private
collect_tail : ANF -> BuildState -> Either String (BuildState, Int)
collect_tail (ALet _ destination value body) state = do
  after_value <- lower_assignment destination value state
  collect_tail body after_value
collect_tail (AV _ (ALocal result)) state = do
  require_bound "Return" result state
  Right (state, result)
collect_tail expression state = do
  let result = fresh_variable_from 0 state.bound_variables
  after_value <- lower_value result expression state
  Right (after_value, result)

private
relations : Int -> List RepresentationConstraint -> (List Int, List Representation)
relations variable [] = ([], [])
relations variable (HasRepresentation constrained representation :: rest) =
  let (neighbours, representations) = relations variable rest in
    if variable == constrained
      then (neighbours, representation :: representations)
      else (neighbours, representations)
relations variable (SameRepresentation left right :: rest) =
  let (neighbours, representations) = relations variable rest in
    if variable == left
      then (right :: neighbours, representations)
      else if variable == right
        then (left :: neighbours, representations)
        else (neighbours, representations)

private
insert_representation : Representation -> List Representation -> List Representation
insert_representation representation representations =
  if elem representation representations then representations
  else representation :: representations

private
insert_representations : List Representation -> List Representation -> List Representation
insert_representations [] accumulated = accumulated
insert_representations (representation :: rest) accumulated =
  insert_representations rest (insert_representation representation accumulated)

private
walk_constraints :
  List RepresentationConstraint -> List Int -> List Int ->
  List Representation -> List Representation
walk_constraints constraints [] visited found = found
walk_constraints constraints (variable :: pending) visited found =
  if elem variable visited
    then walk_constraints constraints pending visited found
    else
      let (neighbours, direct) = relations variable constraints
          found_now = insert_representations direct found
      in walk_constraints constraints (neighbours ++ pending)
           (variable :: visited) found_now

private
infer_representation :
  List RepresentationConstraint -> Int -> Either String Representation
infer_representation constraints variable =
  case walk_constraints constraints [variable] [] [] of
    [] => Left ("No unboxed representation can be inferred for ANF local v" ++ show variable)
    [representation] => Right representation
    representations =>
      Left
        ("ANF local v" ++ show variable ++
         " has conflicting representations: " ++ show representations)

private
allocate_locals :
  List RepresentationConstraint -> List Int -> Int -> List (Int, Local) ->
  Either String (List (Int, Local), Int)
allocate_locals constraints [] next accumulated =
  Right (reverse accumulated, next)
allocate_locals constraints (variable :: rest) next accumulated = do
  representation <- infer_representation constraints variable
  let local = MkLocal variable next representation
  allocate_locals
    constraints
    rest
    (next + representation_slots representation)
    ((variable, local) :: accumulated)

private
find_local : Int -> List (Int, Local) -> Either String Local
find_local variable [] =
  Left ("Internal error: no dense frame home for v" ++ show variable)
find_local variable ((candidate, local) :: rest) =
  if variable == candidate then Right local else find_local variable rest

private
expect_representation : String -> Representation -> Local -> Either String ()
expect_representation role expected local =
  if local.representation == expected
    then Right ()
    else
      Left
        (role ++ " expected " ++ show expected ++
         ", but " ++ show local ++ " has " ++ show local.representation)

private
resolve_instruction :
  List (Int, Local) -> RawInstruction -> Either String Instruction
resolve_instruction locals (RawCopy destination source) = do
  destination_local <- find_local destination locals
  source_local <- find_local source locals
  if destination_local.representation == source_local.representation
    then Right (Copy destination_local source_local)
    else Left "Internal error: copy representation constraint was not solved"
resolve_instruction locals (RawWordConstant destination value) = do
  destination_local <- find_local destination locals
  expect_representation "Word constant" Word32 destination_local
  Right (WordConstant destination_local value)
resolve_instruction locals (RawLoadFloat32 destination buffer index) = do
  destination_local <- find_local destination locals
  buffer_local <- find_local buffer locals
  index_local <- find_local index locals
  expect_representation "Buffer load result" Float32 destination_local
  expect_representation "Buffer load pointer" Float32Pointer buffer_local
  expect_representation "Buffer load index" Word32 index_local
  Right (LoadFloat32 destination_local buffer_local index_local)
resolve_instruction locals (RawFloatBinary operation destination left right) = do
  destination_local <- find_local destination locals
  left_local <- find_local left locals
  right_local <- find_local right locals
  expect_representation "Float binary result" Float32 destination_local
  expect_representation "Float binary left operand" Float32 left_local
  expect_representation "Float binary right operand" Float32 right_local
  Right (FloatBinary operation destination_local left_local right_local)
resolve_instruction locals (RawFloatUnary operation destination value) = do
  destination_local <- find_local destination locals
  value_local <- find_local value locals
  expect_representation "Float unary result" Float32 destination_local
  expect_representation "Float unary operand" Float32 value_local
  Right (FloatUnary operation destination_local value_local)
resolve_instruction locals (RawMakeComplex64 destination magnitude phase) = do
  destination_local <- find_local destination locals
  magnitude_local <- find_local magnitude locals
  phase_local <- find_local phase locals
  expect_representation "Complex64 result" Complex64 destination_local
  expect_representation "Complex64 magnitude" Float32 magnitude_local
  expect_representation "Complex64 phase" Float32 phase_local
  Right (MakeComplex64 destination_local magnitude_local phase_local)
resolve_instruction locals (RawRealToComplex64 destination value) = do
  destination_local <- find_local destination locals
  value_local <- find_local value locals
  expect_representation "real-to-complex result" Complex64 destination_local
  expect_representation "real-to-complex operand" Float32 value_local
  Right (RealToComplex64 destination_local value_local)
resolve_instruction locals (RawComplexMagnitude destination value) = do
  destination_local <- find_local destination locals
  value_local <- find_local value locals
  expect_representation "complex magnitude result" Float32 destination_local
  expect_representation "complex magnitude operand" Complex64 value_local
  Right (ComplexMagnitude destination_local value_local)
resolve_instruction locals (RawComplexPhase destination value) = do
  destination_local <- find_local destination locals
  value_local <- find_local value locals
  expect_representation "complex phase result" Float32 destination_local
  expect_representation "complex phase operand" Complex64 value_local
  Right (ComplexPhase destination_local value_local)
resolve_instruction locals (RawComplexBinary operation destination left right) = do
  destination_local <- find_local destination locals
  left_local <- find_local left locals
  right_local <- find_local right locals
  expect_representation "complex binary result" Complex64 destination_local
  expect_representation "complex binary left operand" Complex64 left_local
  expect_representation "complex binary right operand" Complex64 right_local
  Right (ComplexBinary operation destination_local left_local right_local)
resolve_instruction locals (RawComplexConjugate destination value) = do
  destination_local <- find_local destination locals
  value_local <- find_local value locals
  expect_representation "complex conjugate result" Complex64 destination_local
  expect_representation "complex conjugate operand" Complex64 value_local
  Right (ComplexConjugate destination_local value_local)

private
resolve_instructions :
  List (Int, Local) -> List RawInstruction -> Either String (List Instruction)
resolve_instructions locals [] = Right []
resolve_instructions locals (instruction :: rest) = do
  resolved <- resolve_instruction locals instruction
  more <- resolve_instructions locals rest
  Right (resolved :: more)

private
resolve_locals :
  List (Int, Local) -> List Int -> Either String (List Local)
resolve_locals locals [] = Right []
resolve_locals locals (variable :: rest) = do
  local <- find_local variable locals
  more <- resolve_locals locals rest
  Right (local :: more)

private
aligned_frame_bytes : Int -> Int
aligned_frame_bytes slots =
  let bytes = slots * 4 in
    if bytes <= 8 then 8
    else if bytes `mod` 8 == 0 then bytes else bytes + 4

private
resolve_function :
  String -> List Int -> Int -> Representation -> BuildState ->
  Either String LeafFunction
resolve_function symbol argument_variables result_variable result_representation state = do
  (locals, next_slot) <-
    allocate_locals state.constraints (reverse state.bound_variables) 0 []
  arguments <- resolve_locals locals argument_variables
  instructions <-
    resolve_instructions locals (reverse state.raw_instructions_reversed)
  result <- find_local result_variable locals
  expect_representation "Function result" result_representation result
  Right
    (MkLeafFunction symbol arguments instructions result
      (aligned_frame_bytes next_slot))

||| Validate and lower one exported ANF function into representation-tagged IR.
public export
lower_leaf :
  String -> List Representation -> Representation -> ANFDef ->
  Either String LeafFunction
lower_leaf requested_symbol argument_representations result_representation
           (MkAFun argument_variables body) = do
  symbol <- validate_external_symbol requested_symbol
  if result_representation /= Float32
    then
      Left
        ("Export `" ++ symbol ++
         "` must return RendererPrimitives.Float32, not " ++
         show result_representation)
    else if length argument_variables > 4
      then Left ("Export `" ++ symbol ++ "` has more than four 32-bit softfp ABI arguments")
      else do
        with_arguments <- bind_arguments argument_variables argument_representations empty_state
        (collected, result_variable) <- collect_tail body with_arguments
        let with_result = add_constraint
              (HasRepresentation result_variable result_representation) collected
        resolve_function symbol argument_variables result_variable result_representation with_result
lower_leaf requested_symbol argument_representations result_representation definition =
  Left
    ("Export `" ++ requested_symbol ++
     "` is not a runtime-free function: " ++ show definition)
