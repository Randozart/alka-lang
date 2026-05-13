	.file	"tool_refract.adb"
	.text
	.section	.rodata
.LC0:
	.ascii	"tool_refract.adb"
	.zero	1
	.text
	.align 2
	.p2align 4
	.globl	tool_refract__validate
	.type	tool_refract__validate, @function
tool_refract__validate:
.LFB2:
	.cfi_startproc
	subq	$8, %rsp
	.cfi_def_cfa_offset 16
	testq	%rdi, %rdi
	je	.L10
	movq	%rsi, %rdx
	movq	12(%rdi), %rsi
	testq	%rsi, %rsi
	je	.L6
	movl	20(%rdi), %ecx
	movl	$268435456, %eax
	testl	%ecx, %ecx
	cmove	%eax, %ecx
	testq	%rdx, %rdx
	je	.L11
	xorl	%eax, %eax
	cmpq	%rcx, 8(%rdx)
	jb	.L1
	xorl	%edx, %edx
	leaq	-1(%rsi), %rax
	divq	%rcx
	addq	$1, %rax
	imulq	%rcx, %rax
	cmpq	%rsi, %rax
	setnb	%al
	movzbl	%al, %eax
.L1:
	addq	$8, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L6:
	.cfi_restore_state
	xorl	%eax, %eax
	addq	$8, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
.L10:
	.cfi_restore_state
	movl	$20, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
.L11:
	movl	$35, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
	.cfi_endproc
.LFE2:
	.size	tool_refract__validate, .-tool_refract__validate
	.align 2
	.p2align 4
	.globl	tool_refract__execute
	.type	tool_refract__execute, @function
tool_refract__execute:
.LFB3:
	.cfi_startproc
	testq	%rsi, %rsi
	je	.L21
	movl	20(%rsi), %eax
	movq	12(%rsi), %r8
	movl	$268435456, %ecx
	testl	%eax, %eax
	cmovne	%eax, %ecx
	xorl	%eax, %eax
	testq	%r8, %r8
	je	.L15
	leaq	-1(%r8), %rax
	xorl	%edx, %edx
	divq	%rcx
	addq	$1, %rax
	imulq	$50, %rax, %rax
.L15:
	movq	%rax, 8(%rdi)
	movq	%rdi, %rax
	movb	$1, (%rdi)
	movq	%r8, 16(%rdi)
	movq	$0, 24(%rdi)
	ret
.L21:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	$52, %esi
	leaq	.LC0(%rip), %rdi
	call	__gnat_rcheck_CE_Access_Check@PLT
	.cfi_endproc
.LFE3:
	.size	tool_refract__execute, .-tool_refract__execute
	.globl	tool_refract__max_aperture
	.section	.rodata
	.align 8
	.type	tool_refract__max_aperture, @object
	.size	tool_refract__max_aperture, 8
tool_refract__max_aperture:
	.quad	268435456
	.globl	tool_refract_E
	.data
	.align 2
	.type	tool_refract_E, @object
	.size	tool_refract_E, 2
tool_refract_E:
	.zero	2
	.ident	"GCC: (GNU) 15.1.0"
	.section	.note.GNU-stack,"",@progbits
