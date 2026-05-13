	.file	"tool_signal.adb"
	.text
	.section	.rodata
.LC0:
	.ascii	"tool_signal.adb"
	.zero	1
	.text
	.align 2
	.p2align 4
	.globl	tool_signal__validate
	.type	tool_signal__validate, @function
tool_signal__validate:
.LFB2:
	.cfi_startproc
	testq	%rdi, %rdi
	je	.L7
	movq	4(%rdi), %rax
	movl	$4294967294, %edx
	subq	$1, %rax
	cmpq	%rax, %rdx
	setnb	%al
	movzbl	%al, %eax
	ret
.L7:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	$20, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
	.cfi_endproc
.LFE2:
	.size	tool_signal__validate, .-tool_signal__validate
	.align 2
	.p2align 4
	.globl	tool_signal__execute
	.type	tool_signal__execute, @function
tool_signal__execute:
.LFB3:
	.cfi_startproc
	testq	%rsi, %rsi
	je	.L13
	movdqa	.LC1(%rip), %xmm0
	movq	%rdi, %rax
	movb	$1, (%rdi)
	movq	$0, 24(%rdi)
	movups	%xmm0, 8(%rdi)
	ret
.L13:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	$38, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
	.cfi_endproc
.LFE3:
	.size	tool_signal__execute, .-tool_signal__execute
	.globl	tool_signal_E
	.data
	.align 2
	.type	tool_signal_E, @object
	.size	tool_signal_E, 2
tool_signal_E:
	.zero	2
	.section	.rodata.cst16,"aM",@progbits,16
	.align 16
.LC1:
	.quad	50
	.quad	0
	.ident	"GCC: (GNU) 15.1.0"
	.section	.note.GNU-stack,"",@progbits
