# Speaker tone — ARMv7/Thumb Linux oracle

This directory advances the ARM/Thumb `speaker_tone` row in
`isomorphisms/Idric#85`. The program is handwritten Thumb-2 platform-oracle
code; it is not evidence that the Idriç compiler currently lowers this action.

The no-libc ELF opens `/dev/dsp`, configures Linux OSS-compatible PCM for
unsigned 8-bit mono audio near 8 kHz, constructs a 400 Hz square-wave fixture,
writes 0.25 seconds of samples, drains the playback queue, and exits.

The fixture matches the x86 Linux oracle semantically:

- nominal sample rate: 8000 samples/s;
- period: 20 samples;
- nominal frequency: 400 Hz;
- length: 100 cycles / 2000 samples / 0.25 s;
- high sample: 224;
- low sample: 32.

The Linux syscall ABI and machine code remain ARM-specific. `/dev/dsp` is only
one Linux device adapter below the source-level action “play a tone”; ALSA OSS
emulation supplies this compatibility boundary via `snd-pcm-oss` where enabled.

The ordinary CI check assembles the native ARMv7 Thumb ELF, inspects it, and,
when the host lacks `/dev/dsp`, runs it under `qemu-arm` to verify the explicit
exit-10 no-device path. User-mode QEMU is not speaker acceptance.

Full-system acceptance must boot an Ubuntu armhf guest with a declared virtual
audio device, execute this same native ELF through that guest device stack,
capture QEMU audio output as WAV, and validate the captured frequency and
duration. PCM generation alone does not establish device playback.
