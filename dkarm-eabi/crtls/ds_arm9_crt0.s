@---------------------------------------------------------------------------------
@ DS processor selection
@---------------------------------------------------------------------------------
	.arch	armv5te
	.cpu	arm946e-s
@---------------------------------------------------------------------------------
#define PAGE_4K		(0b01011 << 1)
#define PAGE_8K		(0b01100 << 1)
#define PAGE_16K	(0b01101 << 1)
#define PAGE_32K	(0b01110 << 1)
#define PAGE_64K	(0b01111 << 1)
#define PAGE_128K	(0b10000 << 1)
#define PAGE_256K	(0b10001 << 1)
#define PAGE_512K	(0b10010 << 1)
#define PAGE_1M		(0b10011 << 1)
#define PAGE_2M		(0b10100 << 1)
#define PAGE_4M		(0b10101 << 1)
#define PAGE_8M		(0b10110 << 1)
#define PAGE_16M	(0b10111 << 1)
#define PAGE_32M	(0b11000 << 1)
#define PAGE_64M	(0b11001 << 1)
#define PAGE_128M	(0b11010 << 1)
#define PAGE_256M	(0b11011 << 1)
#define PAGE_512M	(0b11100 << 1)
#define PAGE_1G		(0b11101 << 1)
#define PAGE_2G		(0b11110 << 1)
#define PAGE_4G		(0b11111 << 1)

#define ITCM_LOAD	(1<<19)
#define ITCM_ENABLE	(1<<18)
#define DTCM_LOAD	(1<<17)
#define DTCM_ENABLE	(1<<16)
#define DISABLE_TBIT	(1<<15)
#define ROUND_ROBIN	(1<<14)
#define ALT_VECTORS	(1<<13)
#define ICACHE_ENABLE	(1<<12)
#define BIG_ENDIAN	(1<<7)
#define DCACHE_ENABLE	(1<<2)
#define PROTECT_ENABLE	(1<<0)

	.equ	_libnds_argv,0x02FFFE70

@---------------------------------------------------------------------------------
	.section ".init"
	.global _start
@---------------------------------------------------------------------------------
	.align	4
	.arm
@---------------------------------------------------------------------------------
_start:
@---------------------------------------------------------------------------------
	mov	r0, #0x04000000			@ IME = 0;
	str	r0, [r0, #0x208]

@---------------------------------------------------------------------------------
@ turn the power on for M3
@---------------------------------------------------------------------------------
	ldr     r1, =0x8203
	add	r0,r0,#0x304
	strh    r1, [r0]

	ldr	r1, =0x00002078			@ disable TCM and protection unit
	mcr	p15, 0, r1, c1, c0

@---------------------------------------------------------------------------------
@ Protection Unit Setup added by Sasq
@---------------------------------------------------------------------------------
	@ Disable cache
	mov	r0, #0
	mcr	p15, 0, r0, c7, c5, 0		@ Instruction cache
	mcr	p15, 0, r0, c7, c6, 0		@ Data cache

	@ Wait for write buffer to empty 
	mcr	p15, 0, r0, c7, c10, 4

	ldr	r0, =__dtcm_start
	orr	r0,r0,#0x0a
	mcr	p15, 0, r0, c9, c1,0		@ DTCM base = __dtcm_start, size = 16 KB

	mov r0,#0x20
	mcr	p15, 0, r0, c9, c1,1		@ ITCM base = 0 , size = 32 MB

@---------------------------------------------------------------------------------
@ Setup memory regions similar to Release Version
@---------------------------------------------------------------------------------

	@-------------------------------------------------------------------------
	@ Region 0 - IO registers
	@-------------------------------------------------------------------------
	ldr	r0,=( PAGE_64M | 0x04000000 | 1)	
	mcr	p15, 0, r0, c6, c0, 0

	@-------------------------------------------------------------------------
	@ Region 1 - System ROM
	@-------------------------------------------------------------------------
	ldr	r0,=( PAGE_32K | 0xFFFF0000 | 1)	
	mcr	p15, 0, r0, c6, c1, 0

	@-------------------------------------------------------------------------
	@ Region 2 - alternate vector base
	@-------------------------------------------------------------------------
	ldr	r0,=( PAGE_4K | 0x00000000 | 1)	
	mcr	p15, 0, r0, c6, c2, 0

	@-------------------------------------------------------------------------
	@ Region 3 - DTCM
	@-------------------------------------------------------------------------
	ldr	r0,=__dtcm_start
	orr	r0,r0,#(PAGE_16K | 1)
	mcr	p15, 0, r0, c6, c3, 0

	@-------------------------------------------------------------------------
	@ Region 4 - ITCM
	@-------------------------------------------------------------------------
	ldr	r0,=__itcm_start

	@ align to 32k boundary
	mov	r0,r0,lsr #15
	mov	r0,r0,lsl #15

	orr	r0,r0,#(PAGE_32K | 1)
	mcr	p15, 0, r0, c6, c4, 0

	ldr	r0,=0x4004008
	ldr	r0,[r0]
	ands	r0,r0,#0x8000
	bne	dsi_mode

	@ set sensible stacks to allow bios call
	mov	r0, #0x13		@ Switch to SVC Mode
	msr	cpsr, r0
	mov	r1,#0x03000000
	sub	r1,r1,#0x1000
	mov	sp,r1
	mov	r0, #0x1F		@ Switch to System Mode
	msr	cpsr, r0
	sub	r1,r1,#0x100
	mov	sp,r1
	
	swi	0xf0000

	ldr	r1,=( PAGE_128M | 0x08000000 | 1)	
	cmp	r0,#0
	bne	debug_mode

	ldr	r2,=( PAGE_4M | 0x02000000 | 1)	
	ldr	r3,=( PAGE_4M | 0x02C00000 | 1)	
	mov	r8,#0x02400000

	b	setregions

debug_mode:
	ldr	r2,=( PAGE_8M | 0x02000000 | 1)	
	ldr	r3,=( PAGE_8M | 0x02800000 | 1)	
	mov	r8,#0x02800000
	b	setregions

dsi_mode:
	ldr	r1,=( PAGE_8M  | 0x03000000 | 1)	
	ldr	r2,=( PAGE_16M | 0x02000000 | 1)	
	ldr	r3,=( PAGE_16M | 0x0C000000 | 1)	
	mov	r8,#0x03000000

setregions:

	@-------------------------------------------------------------------------
	@ Region 5 - DS Accessory (GBA Cart) / DSi switchable iwram
	@-------------------------------------------------------------------------
	mcr	p15, 0, r1, c6, c5, 0

	@-------------------------------------------------------------------------
	@ Region 6 - Main Memory
	@-------------------------------------------------------------------------
	mcr	p15, 0, r2, c6, c6, 0

	@-------------------------------------------------------------------------
	@ Region 7 - non cacheable main ram
	@-------------------------------------------------------------------------
	mcr	p15, 0, r3, c6, c7, 0


	@-------------------------------------------------------------------------
	@ Write buffer enable
	@-------------------------------------------------------------------------
	ldr	r0,=0b00000010
	mcr	p15, 0, r0, c3, c0, 0

	@-------------------------------------------------------------------------
	@ DCache & ICache enable
	@-------------------------------------------------------------------------
	ldr	r0,=0b01000010
	mcr	p15, 0, r0, c2, c0, 0
	mcr	p15, 0, r0, c2, c0, 1

	@-------------------------------------------------------------------------
	@ IAccess
	@-------------------------------------------------------------------------
	ldr	r0,=0x33333363
	mcr	p15, 0, r0, c5, c0, 3

	@-------------------------------------------------------------------------
	@ DAccess
	@-------------------------------------------------------------------------
	mcr     p15, 0, r0, c5, c0, 2

	@-------------------------------------------------------------------------
	@ Enable ICache, DCache, ITCM & DTCM
	@-------------------------------------------------------------------------
	mrc	p15, 0, r0, c1, c0, 0
	ldr	r1,= ITCM_ENABLE | DTCM_ENABLE | ICACHE_ENABLE | DCACHE_ENABLE | PROTECT_ENABLE
	orr	r0,r0,r1
	mcr	p15, 0, r0, c1, c0, 0

	mov	r0, #0x12		@ Switch to IRQ Mode
	msr	cpsr, r0
	ldr	sp, =__sp_irq		@ Set IRQ stack

	mov	r0, #0x13		@ Switch to SVC Mode
	msr	cpsr, r0
	ldr	sp, =__sp_svc		@ Set SVC stack

	mov	r0, #0x1F		@ Switch to System Mode
	msr	cpsr, r0
	ldr	sp, =__sp_usr		@ Set user stack

	ldr	r1, =__itcm_lma		@ Copy instruction tightly coupled memory (itcm section) from LMA to VMA
	ldr	r2, =__itcm_start
	ldr	r4, =__itcm_end
	bl	CopyMemCheck

	ldr	r1, =__vectors_lma		@ Copy reserved vectors area (itcm section) from LMA to VMA
	ldr	r2, =__vectors_start
	ldr	r4, =__vectors_end
	bl	CopyMemCheck

	ldr	r1, =__dtcm_lma		@ Copy data tightly coupled memory (dtcm section) from LMA to VMA
	ldr	r2, =__dtcm_start
	ldr	r4, =__dtcm_end
	bl	CopyMemCheck

	bl	checkARGV		@ check and process argv trickery

	ldr	r0, =__bss_start	@ Clear BSS section
	ldr	r1, =__bss_end
	sub	r1, r1, r0
	bl	ClearMem

	ldr	r0, =__sbss_start	@ Clear SBSS section 
	ldr	r1, =__sbss_end
	sub	r1, r1, r0
	bl	ClearMem
	

	ldr	r0, =_libnds_argv

	@ reset heap base
	ldr	r2, [r0,#20]		@ newheap base
	ldr	r1,=fake_heap_start
	str	r2,[r1]

	ldr	r1, =fake_heap_end	@ set heap end
	sub	r8,r8,#0x8000
	str	r8, [r1]

	push	{r0}
	ldr	r3, =initSystem
	blx	r3			@ system initialisation

	ldr	r3, =__libc_init_array	@ global constructors
	blx	r3

	pop	{r0}

	ldr	r1, [r0,#16]		@ argv
	ldr	r0, [r0,#12]		@ argc

	ldr	r3, =main
	blx	r3			@ jump to user code
		
	@ If the user ever returns, go back to passme loop
	ldr	r0, =ILoop
	ldr	r0, [r0]
	ldr	r1, =0x02FFFE78
	str	r0, [r1]
	bx	r1
ILoop:
	b	ILoop

@---------------------------------------------------------------------------------
@ check for a commandline 
@---------------------------------------------------------------------------------
checkARGV:
@---------------------------------------------------------------------------------
	ldr	r0, =_libnds_argv	@ argv structure
	mov	r1, #0
	str	r1, [r0,#12]		@ clear argc
	str	r1, [r0,#16]		@ clear argv
	
	ldr	r3, [r0]		@ argv magic number
	ldr	r2, =0x5f617267		@ '_arg'
	cmp	r3, r2
	strne	r1,[r0,#20]
	bxne	lr			@ bail out if no magic
	
	ldr	r1, [r0, #4]		@ command line address
	ldr	r2, [r0, #8]		@ length of command line

	@ copy to heap
	ldr	r3, =__end__		@ initial heap base
	str	r3, [r0, #4]		@ set command line address

	cmp	r2, #0
	subnes	r4, r3, r1		@ dst-src
	bxeq	lr			@ dst == src || len==0 : nothing to do.
	
	cmphi	r2, r4			@ len > (dst-src)
	bhi	.copybackward

.copyforward:		
	ldrb	r4, [r1], #1
	strb	r4, [r3], #1
	subs	r2, r2, #1
	bne	.copyforward
	b	.copydone

.copybackward:
	subs	r2, r2, #1
	ldrb	r4, [r1, r2]
	strb	r4, [r3, r2]
	bne	.copybackward

.copydone:
	push	{lr}
	ldr	r3, =build_argv
	blx	r3
	pop	{lr}
	bx	lr	


@---------------------------------------------------------------------------------
@ Clear memory to 0x00 if length != 0
@  r0 = Start Address
@  r1 = Length
@---------------------------------------------------------------------------------
ClearMem:
@---------------------------------------------------------------------------------
	mov	r2, #3			@ Round down to nearest word boundary
	add	r1, r1, r2		@ Shouldn't be needed
	bics	r1, r1, r2	@ Clear 2 LSB (and set Z)
	bxeq	lr			@ Quit if copy size is 0

	mov	r2, #0
ClrLoop:
	stmia	r0!, {r2}
	subs	r1, r1, #4
	bne	ClrLoop

	bx	lr

@---------------------------------------------------------------------------------
@ Copy memory if length	!= 0
@  r1 = Source Address
@  r2 = Dest Address
@  r4 = Dest Address + Length
@---------------------------------------------------------------------------------
CopyMemCheck:
@---------------------------------------------------------------------------------
	sub	r3, r4, r2		@ Is there any data to copy?
@---------------------------------------------------------------------------------
@ Copy memory
@  r1 = Source Address
@  r2 = Dest Address
@  r3 = Length
@---------------------------------------------------------------------------------
CopyMem:
@---------------------------------------------------------------------------------
	mov	r0, #3			@ These commands are used in cases where
	add	r3, r3, r0		@ the length is not a multiple of 4,
	bics	r3, r3, r0	@ even though it should be.
	bxeq	lr			@ Length is zero, so exit
CIDLoop:
	ldmia	r1!, {r0}
	stmia	r2!, {r0}
	subs	r3, r3, #4
	bne	CIDLoop

	bx	lr

@---------------------------------------------------------------------------------
	.align
	.pool
	.end
@---------------------------------------------------------------------------------
