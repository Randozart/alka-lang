	.file	"vitriol_types.ads"
	.text
	.align 2
	.p2align 4
	.globl	vitriol_types__op_codeH
	.type	vitriol_types__op_codeH, @function
vitriol_types__op_codeH:
.LFB1:
	.cfi_startproc
	pushq	%r14
	.cfi_def_cfa_offset 16
	.cfi_offset 14, -16
	xorl	%eax, %eax
	leaq	op_codeP.3(%rip), %r10
	movl	$2, %r9d
	pushq	%r13
	.cfi_def_cfa_offset 24
	.cfi_offset 13, -24
	leaq	op_codeT2.1(%rip), %r11
	pushq	%r12
	.cfi_def_cfa_offset 32
	.cfi_offset 12, -32
	pushq	%rbp
	.cfi_def_cfa_offset 40
	.cfi_offset 6, -40
	movq	%rdi, %rbp
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset 3, -48
	movl	4(%rsi), %edx
	leaq	op_codeT1.2(%rip), %rbx
	movslq	(%rsi), %r12
	movl	$-1, %esi
	movl	%edx, %edi
	subl	%r12d, %edi
	leal	-1(%r12), %r8d
	addl	$1, %edi
	cmpl	%edx, %r12d
	movslq	%r8d, %r8
	cmovg	%eax, %edi
	addl	$1, %esi
	xorl	%edx, %edx
	movslq	%esi, %rsi
	movslq	(%r10,%rsi,4), %rcx
	cmpl	%ecx, %edi
	jl	.L3
.L9:
	addq	%r8, %rcx
	subq	%r12, %rcx
	movzbl	0(%rbp,%rcx), %r13d
	movzbl	(%rbx,%rsi), %ecx
	imull	%r13d, %ecx
	addl	%edx, %ecx
	movslq	%ecx, %rdx
	movl	%ecx, %r14d
	imulq	$780903145, %rdx, %rdx
	sarl	$31, %r14d
	sarq	$34, %rdx
	subl	%r14d, %edx
	imull	$22, %edx, %r14d
	movl	%ecx, %edx
	movzbl	(%r11,%rsi), %ecx
	imull	%r13d, %ecx
	subl	%r14d, %edx
	addl	%eax, %ecx
	movslq	%ecx, %rax
	movl	%ecx, %esi
	imulq	$780903145, %rax, %rax
	sarl	$31, %esi
	sarq	$34, %rax
	subl	%esi, %eax
	imull	$22, %eax, %esi
	movl	%ecx, %eax
	subl	%esi, %eax
	xorl	%esi, %esi
	cmpl	$1, %r9d
	je	.L3
	addl	$1, %esi
	movl	$1, %r9d
	movslq	%esi, %rsi
	movslq	(%r10,%rsi,4), %rcx
	cmpl	%ecx, %edi
	jge	.L9
.L3:
	leaq	op_codeG.0(%rip), %rcx
	movslq	%edx, %rdx
	cltq
	movzbl	(%rcx,%rdx), %edx
	movzbl	(%rcx,%rax), %eax
	movl	$3435973837, %ecx
	addl	%edx, %eax
	movq	%rax, %rdx
	imulq	%rcx, %rax
	shrq	$35, %rax
	leal	(%rax,%rax,4), %ecx
	movl	%edx, %eax
	addl	%ecx, %ecx
	subl	%ecx, %eax
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%rbp
	.cfi_def_cfa_offset 32
	popq	%r12
	.cfi_def_cfa_offset 24
	popq	%r13
	.cfi_def_cfa_offset 16
	popq	%r14
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE1:
	.size	vitriol_types__op_codeH, .-vitriol_types__op_codeH
	.align 2
	.p2align 4
	.globl	vitriol_types__drop_typeIP
	.type	vitriol_types__drop_typeIP, @function
vitriol_types__drop_typeIP:
.LFB2:
	.cfi_startproc
	ret
	.cfi_endproc
.LFE2:
	.size	vitriol_types__drop_typeIP, .-vitriol_types__drop_typeIP
	.align 2
	.p2align 4
	.globl	vitriol_types__vial_constraintsIP
	.type	vitriol_types__vial_constraintsIP, @function
vitriol_types__vial_constraintsIP:
.LFB19:
	.cfi_startproc
	ret
	.cfi_endproc
.LFE19:
	.size	vitriol_types__vial_constraintsIP, .-vitriol_types__vial_constraintsIP
	.align 2
	.p2align 4
	.globl	vitriol_types__tool_resultIP
	.type	vitriol_types__tool_resultIP, @function
vitriol_types__tool_resultIP:
.LFB4:
	.cfi_startproc
	movq	$0, 24(%rdi)
	ret
	.cfi_endproc
.LFE4:
	.size	vitriol_types__tool_resultIP, .-vitriol_types__tool_resultIP
	.align 2
	.p2align 4
	.globl	vitriol_types__chunk_count
	.type	vitriol_types__chunk_count, @function
vitriol_types__chunk_count:
.LFB5:
	.cfi_startproc
	testq	%rsi, %rsi
	setne	%cl
	testq	%rdi, %rdi
	setne	%dl
	xorl	%eax, %eax
	testb	%dl, %cl
	je	.L13
	leaq	-1(%rdi), %rax
	xorl	%edx, %edx
	divq	%rsi
	addq	$1, %rax
.L13:
	ret
	.cfi_endproc
.LFE5:
	.size	vitriol_types__chunk_count, .-vitriol_types__chunk_count
	.section	.rodata
	.align 16
	.type	op_codeG.0, @object
	.size	op_codeG.0, 22
op_codeG.0:
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	4
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	5
	.byte	2
	.byte	0
	.byte	1
	.byte	4
	.byte	0
	.byte	7
	.byte	1
	.byte	3
	.byte	5
	.align 2
	.type	op_codeT2.1, @object
	.size	op_codeT2.1, 2
op_codeT2.1:
	.byte	6
	.byte	19
	.align 2
	.type	op_codeT1.2, @object
	.size	op_codeT1.2, 2
op_codeT1.2:
	.byte	20
	.byte	17
	.align 8
	.type	op_codeP.3, @object
	.size	op_codeP.3, 8
op_codeP.3:
	.long	1
	.long	3
	.globl	vitriol_types__op_codeN
	.align 16
	.type	vitriol_types__op_codeN, @object
	.size	vitriol_types__op_codeN, 16
vitriol_types__op_codeN:
	.byte	1
	.byte	6
	.byte	10
	.byte	15
	.byte	20
	.byte	24
	.byte	30
	.byte	35
	.byte	42
	.byte	46
	.byte	53
	.zero	5
	.globl	vitriol_types__op_codeS
	.align 32
	.type	vitriol_types__op_codeS, @object
	.size	vitriol_types__op_codeS, 52
vitriol_types__op_codeS:
	.ascii	"CLAIMFLOWSHIFTFENCESYNCSIGNALLIMITREFRACTPIPEUNKNOWN"
	.globl	vitriol_types_E
	.data
	.align 2
	.type	vitriol_types_E, @object
	.size	vitriol_types_E, 2
vitriol_types_E:
	.zero	2
	.ident	"GCC: (GNU) 15.1.0"
	.section	.note.GNU-stack,"",@progbits
