	.file	"tool_flow.adb"
	.text
	.section	.rodata
.LC0:
	.ascii	"tool_flow.adb"
	.zero	1
	.text
	.align 2
	.p2align 4
	.globl	tool_flow__validate
	.type	tool_flow__validate, @function
tool_flow__validate:
.LFB2:
	.cfi_startproc
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	testq	%rdi, %rdi
	je	.L12
	movl	20(%rdi), %eax
	testl	%eax, %eax
	je	.L5
	testq	%rsi, %rsi
	je	.L13
	xorl	%edx, %edx
	cmpq	%rax, 8(%rsi)
	jb	.L1
	cmpb	$0, 24(%rsi)
	je	.L1
	movq	%rax, %rcx
	addq	4(%rdi), %rcx
	jc	.L1
	xorl	%edx, %edx
	addq	12(%rdi), %rax
	setnc	%dl
.L1:
	movl	%edx, %eax
	addq	$8, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L5:
	.cfi_restore_state
	xorl	%edx, %edx
	movl	%edx, %eax
	addq	$8, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L12:
	.cfi_restore_state
	movl	$20, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
.L13:
	movl	$24, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
	.cfi_endproc
.LFE2:
	.size	tool_flow__validate, .-tool_flow__validate
	.align 2
	.p2align 4
	.globl	tool_flow__execute
	.type	tool_flow__execute, @function
tool_flow__execute:
.LFB3:
	.cfi_startproc
	testq	%rsi, %rsi
	je	.L19
	movl	20(%rsi), %eax
	movb	$1, (%rdi)
	movq	$0, 24(%rdi)
	movq	%rax, %rdx
	movq	%rax, 16(%rdi)
	movq	%rdi, %rax
	shrq	$10, %rdx
	movq	%rdx, 8(%rdi)
	ret
.L19:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	$48, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
	.cfi_endproc
.LFE3:
	.size	tool_flow__execute, .-tool_flow__execute
	.globl	tool_flow_E
	.data
	.align 2
	.type	tool_flow_E, @object
	.size	tool_flow_E, 2
tool_flow_E:
	.zero	2
	.ident	"GCC: (GNU) 15.1.0"
	.section	.note.GNU-stack,"",@progbits
