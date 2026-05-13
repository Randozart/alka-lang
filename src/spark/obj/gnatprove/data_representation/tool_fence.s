	.file	"tool_fence.adb"
	.text
	.section	.rodata
.LC0:
	.ascii	"tool_fence.adb"
	.zero	1
	.text
	.align 2
	.p2align 4
	.globl	tool_fence__validate
	.type	tool_fence__validate, @function
tool_fence__validate:
.LFB2:
	.cfi_startproc
	testq	%rdi, %rdi
	je	.L7
	movq	4(%rdi), %rax
	subq	$1, %rax
	cmpq	$9999999, %rax
	setbe	%al
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
	.size	tool_fence__validate, .-tool_fence__validate
	.align 2
	.p2align 4
	.globl	tool_fence__execute
	.type	tool_fence__execute, @function
tool_fence__execute:
.LFB3:
	.cfi_startproc
	testq	%rsi, %rsi
	je	.L17
	movq	4(%rsi), %rdx
	xorl	%eax, %eax
	testq	%rdx, %rdx
	je	.L10
	.p2align 4
	.p2align 4
	.p2align 3
.L11:
	addq	$100, %rax
	cmpq	%rdx, %rax
	jb	.L11
.L10:
	movq	%rax, 8(%rdi)
	movq	%rdi, %rax
	movb	$1, (%rdi)
	movq	$0, 16(%rdi)
	movq	$0, 24(%rdi)
	ret
.L17:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	$38, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
	.cfi_endproc
.LFE3:
	.size	tool_fence__execute, .-tool_fence__execute
	.globl	tool_fence_E
	.data
	.align 2
	.type	tool_fence_E, @object
	.size	tool_fence_E, 2
tool_fence_E:
	.zero	2
	.ident	"GCC: (GNU) 15.1.0"
	.section	.note.GNU-stack,"",@progbits
