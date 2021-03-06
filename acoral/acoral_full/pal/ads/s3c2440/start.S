;define the stack size
;定义堆栈的大小
FIQ_STACK_LEGTH         EQU         100
IRQ_STACK_LEGTH         EQU         200	             ;every layer need 9 bytes stack , permit 8 layer .每层嵌套需要9个字堆栈，允许8层嵌套
ABT_STACK_LEGTH         EQU         100
UND_STACK_LEGTH         EQU         100
SYS_STACK_LEGTH         EQU         400

;定义模式
NoInt       EQU 0xC0
USR32Mode   EQU 0x10
SVC32Mode   EQU 0x13
SYS32Mode   EQU 0x1f
IRQ32Mode   EQU 0x12
FIQ32Mode   EQU 0x11
MODE_MASK	EQU	0x1f

;The imported labels        
;引入的外部标号在这声明
    IMPORT  HAL_INTR_ENTRY                   ;Fast interrupt exceptions handler 快速中断异常处理程序
    IMPORT  acoral_start                          ;The entry point to the main function C语言主程序入口 
    IMPORT 	EXP_HANDLER                          ;err entry  

;The emported labels        
;给外部使用的标号在这声明
	EXPORT  heap_end
    EXPORT  heap_start
    EXPORT  StackIrq
	EXPORT	MMU_base

;全局变量在这里声明


	EXPORT  Reset



	;INTCON 		EQU		0x01E00000
INTMSK 			EQU		0x4A000008
LOCKTIME		EQU		0x4C000000
PLLCON 			EQU		0x4C000004
CLKDIVN			EQU		0x4C000014
WTCON  			EQU		0x53000000
;vPLLCON 		EQU		0x48032				;40M hz
MEM_CTL_BASE	EQU		0x48000000
M_DIVN    		EQU		0x3


	CODE32
	
	AREA	vectors, CODE,READONLY
	
	ENTRY
	
Reset

	b ResetHandler
	LDR 	PC,	HandleUndef	;handler for Undefined mode
	LDR 	PC,	HandleSWI       ;handler for SWI interrupt
	LDR 	PC,	HandlePabort	;handler for PAbort
	LDR 	PC,	HandleDabort	;handler for DAbort
	B       .			        ;reserved
	LDR		PC, HandleIRQ 	;handler for IRQ interrupt
	LDR		PC,	HandleFIQ	;handler for FIQ interrupt
	
	B		.
	
	
	

;@****************************************************************
;@ intvector setup
;@****************************************************************

;ResetHandler		DCD		ResetHandler
HandleFIQ			DCD		acoral_start
HandleIRQ			DCD		HAL_INTR_ENTRY
HandleUndef			DCD		acoral_start
HandleSWI			DCD		acoral_start
HandleDabort		DCD		acoral_start
HandlePabort		DCD 	acoral_start



;*************************************************************
;*************************************************************
;*堆栈初始化
;*************************************************************

InitStack    
        MOV     R0, LR
;Build the SVC stack
;设置中断模式堆栈
 		MSR     CPSR_c, #0xd2
        LDR     SP, StackIrq
;Build the FIQ stack	
;设置快速中断模式堆栈
        MSR     CPSR_c, #0xd1
        LDR     SP, StackFiq
;Build the DATAABORT stack
;设置中止模式堆栈
        MSR     CPSR_c, #0xd7
        LDR     SP, StackAbt
;Build the UDF stack
;设置未定义模式堆栈
        MSR     CPSR_c, #0xdb
        LDR     SP, StackUnd
        
        MSR     CPSR_c, #0xd3
        LDR     SP, StackSys

;Build the SYS stack
;设置系统模式堆栈
        MSR     CPSR_c, #0xdf
        LDR     SP, StackSys
 
        MOV     PC, R0
        
        
        
        
        
;@****************************************************************
;@             ResetHandler fuction
;@****************************************************************

ResetHandler
    
    ;set the cpu to svc32 mode
	mrs 	r0,cpsr
	bic 	r0,r0,#0x1f
	orr 	r0,r0,#0x13
	msr 	cpsr_c,r0
       

    
       	;@ disable watch dog timer
	mov	r1, #0x53000000
	mov	r2, #0x0
	str	r2, [r1]

	;disable all interrupts
	
	ldr 	r1,=INTMSK
	ldr 	r0, =0xffffffff
	str 	r0, [r1]
	
	
	;@ initialise system clocks
	;mov	r1, #LOCKTIME
	;mvn	r2, #0xff000000
	;str	r2, [r1]

;@1:2:4
	
	;ldr	r1, =CLKDIVN
	;mov	r2, #M_DIVN
	;str	r2, [r1]

	mrc	p15, 0, r1, c1, c0, 0		;@ read ctrl register
	orr	r1, r1, #0xc0000000			;@ Asynchronous
	mcr	p15, 0, r1, c1, c0, 0		;@ write ctrl register


;@ the default flck=120M
;@	mov	r1, #CLK_CTL_BASE
;@	ldr 	r2, =vMPLLCON	       	;@ clock user set
;@	str	r2, [r1, #oMPLLCON]

	;bl	memsetup

	bl     InitStack

	ldr  r0,=bss_start
	ldr  r1,=bss_end
	bl    mem_clear

    	

	ldr    pc,=acoral_start		;@ call sys_start
	b 	.



;@***************************************************************
;@                       鍫嗘爤鍒濆鍖�
;@***************************************************************

;InitStacks
;	mov r2,lr
;	mrs	r0,cpsr
;	bic	r0,r0,#MODE_MASK
;	orr	r1,r0,#UND_MODE|NOINT
;	msr	cpsr_cxsf,r1		;@UndefMode
;	ldr	sp,=UDF_stack		;@ UndefStack=0x33FF_5C00
;
;	orr	r1,r0,#ABT_MODE|NOINT
;	msr	cpsr_cxsf,r1		;@AbortMode
;	ldr	sp,=ABT_stack		;@ AbortStack=0x33FF_6000

;	orr	r1,r0,#IRQ_MODE|NOINT
;	msr	cpsr_cxsf,r1		;@IRQMode
;	ldr	sp,=IRQ_stack		;@ IRQStack=0x33FF_7000

;	orr	r1,r0,#FIQ_MODE|NOINT
;	msr	cpsr_cxsf,r1		;@FIQMode
;	ldr	sp,=FIQ_stack		;@ FIQStack=0x33FF_8000
;
;	bic	r0,r0,#MODE_MASK|NOINT
;	orr	r1,r0,#SVC_MODE
;	msr	cpsr_cxsf,r1		;@SVCMode
;	ldr	sp,=SVC_stack		;@ SVCStack=0x33FF_5800
;	mov	pc,r2
;*/
;@***************************************************************
;@ initialise the static memory
;@ set memory control registers
;@***************************************************************

memsetup
	mov	r1, #MEM_CTL_BASE
	adrl	r2, mem_cfg_val
	add	r3, r1, #52
1
	ldr	r4, [r2], #4
	str	r4, [r1], #4
	cmp	r1, r3
	bne	%B1
	mov	pc, lr

;@***************************************************************
;@ clear memory
;@ r0: start address
;@ r1: length
;@***************************************************************

mem_clear
	mov r2,#0
1
	str r2,[r0],#4
	cmp r0,r1
	blt %B1
	mov pc,lr


;@***************************************************************
;@ Data Area
;@ Memory configuration values
;@***************************************************************

ALIGN
mem_cfg_val
vBWSCON		DCD		0x22111110
vBANKCON0	DCD		0x00000700
vBANKCON1	DCD		0x00000700
vBANKCON2	DCD		0x00000700
vBANKCON3	DCD		0x00000700
vBANKCON4	DCD		0x00000700
vBANKCON5	DCD		0x00000700
vBANKCON6	DCD		0x00018005
vBANKCON7	DCD		0x00018005
vREFRESH	DCD		0x008e0459
vBANKSIZE	DCD		0xb2
vMRSRB6		DCD		0x30
vMRSRB7		DCD		0x30
;**************************************************************
;*堆栈分配;/* 分配堆栈空间 */
;**************************************************************
StackIrq           DCD     IrqStackSpace + (IRQ_STACK_LEGTH - 1)* 4
StackFiq           DCD     FiqStackSpace + (FIQ_STACK_LEGTH - 1)* 4
StackAbt           DCD     AbtStackSpace + (ABT_STACK_LEGTH - 1)* 4
StackUnd           DCD     UndtStackSpace + (UND_STACK_LEGTH - 1)* 4
StackSys           DCD     SysStackSpace + (SYS_STACK_LEGTH - 1)* 4





        AREA    MyStacks, DATA, NOINIT, ALIGN=2
IrqStackSpace      SPACE   IRQ_STACK_LEGTH * 4  ;Stack spaces for Interrupt ReQuest Mode 中断模式堆栈空间
FiqStackSpace      SPACE   FIQ_STACK_LEGTH * 4  ;Stack spaces for Fast Interrupt reQuest Mode 快速中断模式堆栈空间
AbtStackSpace      SPACE   ABT_STACK_LEGTH * 4  ;Stack spaces for Suspend Mode 中止义模式堆栈空间
UndtStackSpace     SPACE   UND_STACK_LEGTH * 4  ;Stack spaces for Undefined Mode 未定义模式堆栈
SysStackSpace      SPACE   SYS_STACK_LEGTH * 4  ;Stack spaces for Undefin


;***********************************************************
;*段名称定义
;***********************************************************
        AREA    Bss_Start, DATA, NOINIT
bss_start    SPACE   1

        AREA    Bss_End, DATA, NOINIT
bss_end   SPACE   1

        AREA    HeapStart, DATA, NOINIT
heap_start    SPACE   1

        AREA    HeapEnd, DATA, NOINIT
heap_end   SPACE   1

        AREA   MMU, DATA, NOINIT
MMU_base   SPACE   1






	
	END