	.file	"tool_shift.adb"
	.text
	.section	.rodata
.LC0:
	.ascii	"tool_shift.adb"
	.zero	1
	.text
	.align 2
	.p2align 4
	.globl	tool_shift__validate
	.type	tool_shift__validate, @function
tool_shift__validate:
.LFB2:
	.cfi_startproc
	testq	%rdi, %rdi
	je	.L9
	movq	4(%rdi), %rdx
	xorl	%eax, %eax
	cmpq	$268435456, %rdx
	ja	.L1
	xorl	%eax, %eax
	testl	$4095, %edx
	sete	%al
.L1:
	ret
.L9:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	$19, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
	.cfi_endproc
.LFE2:
	.size	tool_shift__validate, .-tool_shift__validate
	.align 2
	.p2align 4
	.globl	tool_shift__execute
	.type	tool_shift__execute, @function
tool_shift__execute:
.LFB3:
	.cfi_startproc
	testq	%rsi, %rsi
	je	.L15
	movdqa	.LC1(%rip), %xmm0
	movq	%rdi, %rax
	movb	$1, (%rdi)
	movq	$0, 24(%rdi)
	movups	%xmm0, 8(%rdi)
	ret
.L15:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	$37, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
	.cfi_endproc
.LFE3:
	.size	tool_shift__execute, .-tool_shift__execute
	.globl	tool_shift__max_aperture
	.section	.rodata
	.align 8
	.type	tool_shift__max_aperture, @object
	.size	tool_shift__max_aperture, 8
tool_shift__max_aperture:
	.quad	268435456
	.globl	tool_shift_E
	.data
	.align 2
	.type	tool_shift_E, @object
	.size	tool_shift_E, 2
tool_shift_E:
	.zero	2
	.section	.rodata.cst16,"aM",@progbits,16
	.align 16
.LC1:
	.quad	10
	.quad	0
	.ident	"GCC: (GNU) 15.1.0"
	.section	.note.GNU-stack,"",@progbits
