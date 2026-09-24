.syntax unified
.arch armv7-a
.fpu vfpv3-d16
.thumb
.text

.global _start
.type _start, %function
.thumb_func
_start:
        sub     sp, sp, #16
        mov     r4, sp

        @ Primitive arithmetic: 1.5 and 0.5 are exact E3M2 inputs.
        movs    r0, #0x0e
        movs    r1, #0x08
        bl      e3m2_add_test
        strb    r0, [r4, #0]

        movs    r0, #0x0e
        movs    r1, #0x08
        bl      e3m2_sub_test
        strb    r0, [r4, #1]

        movs    r0, #0x0e
        movs    r1, #0x08
        bl      e3m2_mul_test
        strb    r0, [r4, #2]

        movs    r0, #0x0e
        movs    r1, #0x08
        bl      e3m2_div_test
        strb    r0, [r4, #3]

        movs    r0, #0x0e
        bl      e3m2_square_test
        strb    r0, [r4, #4]

        movs    r0, #0x0e
        bl      e3m2_cube_test
        strb    r0, [r4, #5]

        movs    r0, #0x10
        bl      e3m2_sqrt_test
        strb    r0, [r4, #6]

        @ Dakota adjustment estimate:
        @ [delta camber] = [-1.3 -0.7] [front]
        @ [delta caster]   [-1    1 ] [rear ]
        @ Use front=+1, rear=-0.5.
        @ E3M2 input payloads correspond to -1.25, -0.75, -1, +1, +1, -0.5.
        movs    r0, #0x2d
        movs    r1, #0x2a
        movs    r2, #0x0c
        movs    r3, #0x28
        bl      e3m2_dot2_test
        strb    r0, [r4, #7]

        movs    r0, #0x2c
        movs    r1, #0x0c
        movs    r2, #0x0c
        movs    r3, #0x28
        bl      e3m2_dot2_test
        strb    r0, [r4, #8]

        @ Rotate (3,4) by one steering-wheel turn / 17.4.
        @ theta=20.689655 deg; cos(theta)->0.875 E3M2, sin(theta)->0.375 E3M2.
        movs    r0, #0x0b
        movs    r1, #0x06
        movs    r2, #0x12
        movs    r3, #0x14
        bl      e3m2_rotate_x_test
        strb    r0, [r4, #9]

        movs    r0, #0x06
        movs    r1, #0x0b
        movs    r2, #0x12
        movs    r3, #0x14
        bl      e3m2_rotate_y_test
        strb    r0, [r4, #10]

        @ Caster from a 4-degree camber swing:
        @ 4 * (1 / (2 sin(theta))); multiplier 1.415204... -> E3M2 1.5.
        movs    r0, #0x14
        movs    r1, #0x0e
        bl      e3m2_mul_test
        strb    r0, [r4, #11]

        @ Emit raw E3M2 payloads. The host observer prints reference/observed/residue.
        movs    r0, #1
        mov     r1, r4
        movs    r2, #12
        movs    r7, #4
        svc     #0

        add     sp, sp, #16
        movs    r0, #0
        movs    r7, #1
        svc     #0

.size _start, .-_start
.section .note.GNU-stack,"",%progbits
