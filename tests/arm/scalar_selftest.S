.syntax unified
.arch armv7-a
.fpu vfpv3-d16
.thumb
.text

.global _start
.type _start, %function
.thumb_func
_start:
        @ Bits8 is a real primitive scalar and canonicalizes to eight bits.
        ldr     r0, =0x123400ff
        bl      bits8_identity
        cmp     r0, #255
        bne     fail_1

        movs    r0, #250
        movs    r1, #10
        bl      bits8_add_test
        cmp     r0, #4
        bne     fail_2

        movs    r0, #3
        movs    r1, #5
        bl      bits8_sub_test
        cmp     r0, #254
        bne     fail_3

        movs    r0, #255
        movs    r1, #255
        bl      bits8_mul_test
        cmp     r0, #1
        bne     fail_4

        @ IEEE binary16: identity, exact conversion, subnormal, arithmetic.
        ldr     r0, =0x12343c00
        bl      float16_identity
        ldr     r1, =0x00003c00
        cmp     r0, r1
        bne     fail_5

        ldr     r0, =0x00003c00
        bl      float16_to_f32_test
        ldr     r1, =0x3f800000
        cmp     r0, r1
        bne     fail_6

        ldr     r0, =0x3f800000
        bl      f32_to_float16_test
        ldr     r1, =0x00003c00
        cmp     r0, r1
        bne     fail_7

        movs    r0, #1
        bl      float16_to_f32_test
        ldr     r1, =0x33800000
        cmp     r0, r1
        bne     fail_8

        ldr     r0, =0x00003e00
        ldr     r1, =0x00003800
        bl      float16_add_test
        ldr     r1, =0x00004000
        cmp     r0, r1
        bne     fail_9

        ldr     r0, =0x00004000
        ldr     r1, =0x00003800
        bl      float16_sub_test
        ldr     r1, =0x00003e00
        cmp     r0, r1
        bne     fail_10

        ldr     r0, =0x00003e00
        ldr     r1, =0x00004000
        bl      float16_mul_test
        ldr     r1, =0x00004200
        cmp     r0, r1
        bne     fail_11

        ldr     r0, =0x00004200
        ldr     r1, =0x00004000
        bl      float16_div_test
        ldr     r1, =0x00003e00
        cmp     r0, r1
        bne     fail_12

        @ OCP FP8 E4M3.
        ldr     r0, =0x1234003c
        bl      e4m3_identity
        cmp     r0, #0x3c
        bne     fail_13

        movs    r0, #0x3c
        bl      e4m3_to_f32_test
        ldr     r1, =0x3fc00000
        cmp     r0, r1
        bne     fail_14

        ldr     r0, =0x3fc00000
        bl      f32_to_e4m3_test
        cmp     r0, #0x3c
        bne     fail_15

        movs    r0, #1
        bl      e4m3_to_f32_test
        ldr     r1, =0x3b000000
        cmp     r0, r1
        bne     fail_16

        movs    r0, #0x3c
        movs    r1, #0x30
        bl      e4m3_add_test
        cmp     r0, #0x40
        bne     fail_17

        movs    r0, #0x40
        movs    r1, #0x30
        bl      e4m3_sub_test
        cmp     r0, #0x3c
        bne     fail_18

        movs    r0, #0x3c
        movs    r1, #0x40
        bl      e4m3_mul_test
        cmp     r0, #0x44
        bne     fail_19

        movs    r0, #0x44
        movs    r1, #0x40
        bl      e4m3_div_test
        cmp     r0, #0x3c
        bne     fail_20

        @ OCP FP8 E5M2.
        movs    r0, #0x3e
        bl      e5m2_to_f32_test
        ldr     r1, =0x3fc00000
        cmp     r0, r1
        bne     fail_21

        ldr     r0, =0x3fc00000
        bl      f32_to_e5m2_test
        cmp     r0, #0x3e
        bne     fail_22

        movs    r0, #1
        bl      e5m2_to_f32_test
        ldr     r1, =0x37800000
        cmp     r0, r1
        bne     fail_23

        movs    r0, #0x3e
        movs    r1, #0x38
        bl      e5m2_add_test
        cmp     r0, #0x40
        bne     fail_24

        movs    r0, #0x40
        movs    r1, #0x38
        bl      e5m2_sub_test
        cmp     r0, #0x3e
        bne     fail_25

        movs    r0, #0x3e
        movs    r1, #0x40
        bl      e5m2_mul_test
        cmp     r0, #0x42
        bne     fail_26

        movs    r0, #0x42
        movs    r1, #0x40
        bl      e5m2_div_test
        cmp     r0, #0x3e
        bne     fail_27

        @ OCP FP6 E3M2. High container bits are not part of the scalar.
        ldr     r0, =0x1234000e
        bl      e3m2_identity
        cmp     r0, #0x0e
        bne     fail_28

        movs    r0, #0x0e
        bl      e3m2_to_f32_test
        ldr     r1, =0x3fc00000
        cmp     r0, r1
        bne     fail_29

        ldr     r0, =0x3fc00000
        bl      f32_to_e3m2_test
        cmp     r0, #0x0e
        bne     fail_30

        movs    r0, #1
        bl      e3m2_to_f32_test
        ldr     r1, =0x3d800000
        cmp     r0, r1
        bne     fail_31

        movs    r0, #0x0e
        movs    r1, #0x08
        bl      e3m2_add_test
        cmp     r0, #0x10
        bne     fail_32

        movs    r0, #0x10
        movs    r1, #0x08
        bl      e3m2_sub_test
        cmp     r0, #0x0e
        bne     fail_33

        movs    r0, #0x0e
        movs    r1, #0x10
        bl      e3m2_mul_test
        cmp     r0, #0x12
        bne     fail_34

        movs    r0, #0x12
        movs    r1, #0x10
        bl      e3m2_div_test
        cmp     r0, #0x0e
        bne     fail_35

        @ Ootomo-Naruse unsigned E5M3 storage scalar.
        ldr     r0, =0x12340078
        bl      e5m3_identity
        cmp     r0, #0x78
        bne     fail_36

        ldr     r0, =0x3f800000
        bl      f32_to_e5m3_test
        cmp     r0, #0x78
        bne     fail_37

        movs    r0, #0x78
        bl      e5m3_to_f32_test
        ldr     r1, =0x3f880000
        cmp     r0, r1
        bne     fail_38

        movs    r0, #0
        b       exit

fail_1:  movs r0, #1;  b exit
fail_2:  movs r0, #2;  b exit
fail_3:  movs r0, #3;  b exit
fail_4:  movs r0, #4;  b exit
fail_5:  movs r0, #5;  b exit
fail_6:  movs r0, #6;  b exit
fail_7:  movs r0, #7;  b exit
fail_8:  movs r0, #8;  b exit
fail_9:  movs r0, #9;  b exit
fail_10: movs r0, #10; b exit
fail_11: movs r0, #11; b exit
fail_12: movs r0, #12; b exit
fail_13: movs r0, #13; b exit
fail_14: movs r0, #14; b exit
fail_15: movs r0, #15; b exit
fail_16: movs r0, #16; b exit
fail_17: movs r0, #17; b exit
fail_18: movs r0, #18; b exit
fail_19: movs r0, #19; b exit
fail_20: movs r0, #20; b exit
fail_21: movs r0, #21; b exit
fail_22: movs r0, #22; b exit
fail_23: movs r0, #23; b exit
fail_24: movs r0, #24; b exit
fail_25: movs r0, #25; b exit
fail_26: movs r0, #26; b exit
fail_27: movs r0, #27; b exit
fail_28: movs r0, #28; b exit
fail_29: movs r0, #29; b exit
fail_30: movs r0, #30; b exit
fail_31: movs r0, #31; b exit
fail_32: movs r0, #32; b exit
fail_33: movs r0, #33; b exit
fail_34: movs r0, #34; b exit
fail_35: movs r0, #35; b exit
fail_36: movs r0, #36; b exit
fail_37: movs r0, #37; b exit
fail_38: movs r0, #38

exit:
        movs    r7, #1
        svc     #0

.size _start, .-_start
.section .note.GNU-stack,"",%progbits
