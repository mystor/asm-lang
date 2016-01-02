This is (going to be) a very simple compiler written in x86-64 assembly.

Right now, its a mechanism to help me learn x86-64 assembly.

The only build platform which is working is `elf64` on Linux, although hopefully `macho64` will be supported at some point too.


## NOTES TO SELF
* Command to disassemble output file and display what I actually emitted

    objdump -D output -mi386:x86-64 -b binary --start-address=0xb0 -M intel
