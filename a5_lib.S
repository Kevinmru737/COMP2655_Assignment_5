; Name:        Kevin Oh
; Email:       koh705@mtroyal.ca
; Course:      COMP2655-002
; Assignment:  Assignment #5
; Due Date:    December 7, 2023
; Filename:    A5_LIB.S
; Instructor:  Paul Pospisil
; 
; Purpose: To implement a 32-bit IEEE floating point library for the
;		MC68000 to print and add these types of values
;	   
; Program Details:
; 	Input: A test driver will utilize this library with predefined
;	       32-bit IEEE floating point pairs and call the addition,
;	       printing, and hex conversion subroutines.
;
;	Output: The test driver will indicate whether the library has
;		passed its test values, and if any test cases fail, if
;		any.	
;
;	Assumptions:
;		Full error checking required for IEEE floating 
;		point numbers is not complete. Denormalized,
;		+ or - infinity, and NaN (not a number) errors
;		are not handled.
;
; 	Limitations:
;		These subroutines require valid 32-bit IEEE
;		floating point numbers and does not check for
;		invalid inputs.
;
; Modification History:
;		Nov. 27, 2023:
;			-Documentation/algorithm design
;			-Implementation of:
;				-printCstring
;				-hex2string
;
;		Nov. 30, 2023:
;			-Implementation of:
;				-packFloat
;				-unpackFloat
;			
;		Dec. 2, 2023:
;			-Implementation of:
;				-scale
;				-reNormalize
;
;		Dec. 3, 2023:
;			-Implementation of:
;				-add_FP
;		
; Program Status:
;	What is completed/working:
;		add_FP:		IMPLEMENTED
;		unpackFloat:	IMPLEMENTED
;		packFloat:	IMPLEMENTED
;		scale:		IMPLEMENTED
;		renormalize:	IMPLEMENTED
;		printCstring:	IMPLEMENTED
;		hex2string:	IMPLEMENTED
;
;		All test cases returned the correct values.
;		All aspects of the program are assumed to be working.
;
;	Testing:
;		*20 out of 20 tests passed*
;		
;		Test Plan:
;			The testing for this program will be done via
;			a provided test driver.
;
;		Untested: The provided test driver is assumed to provide
;			  a comprehensive list of values, no other
;			  test cases have been added.
;
;			  Detailed and comprehensive testing has not
;			  been completed for each individual
;			  subroutine.
;
;		Not Working:
;			Nothing found.
;			
	xdef	add_FP
	xdef	unpackFloat
	xdef	packFloat
	xdef	scale
	xdef	renormalize
	xdef	printCstring
	xdef	hex2string

	include	gemdos.i

;struct floatRecord
FLOAT_RECORD	equ	6

SIGN		equ	0
BIASED_EXP	equ	1
MANTISSA	equ	2

;constant section
GEMDOS	equ	1

NULL	equ	0

;----- SUBROUTINE: add_FP -----
;
;----- float add_FP (float operand1, float operand2) -----
;
; PURPOSE: Adds two 32-bit IEEE floating point numbers and returns
;	   the result.
;
; DETAILS: This function utilizes unpackFloat, packFloat,
;	   scale, and renormalize to decompose each 32-bit
;	   IEEE floating point number into its component 
;	   parts, possibly scale one of the numbers, perform
;	   the addition using sign magnitude operations, 
;	   normalize the result and then recompose the number
;	   into 32-bit IEEE floating point notation.
;
; FORMULAE/AL-QUIRKS:
;	All addition performed is based on Signed Magnitude
;	notation. Thus the cases for when two positive
;	numbers are added is different than when
;	a positive and negative number are added.
;
;	(Addition when signs are equal)
;	For addition of IEEE floating point numbers there
;	is a possibility of there being a carry out of the
;	MS bit, indicating that the sum cannot fit within
;	the range of the previous exponent value. To be able
;	to check if the carry bit in the status register is
;	set, after the numbers are scaled but before they
;	are added both mantissas will be shifted to the
;	right by 1 and the 31st (MS) bit will now be an 
;	indication of a carry out occuring during the
;	addition. This is used by renormalize.
;
;	(Addition when signs are not equal)
;	For subtraction (addition of negative numbers)
;	the mantissa of the sum may no longer have a 
;	leading one, indicating the exponent is too large
;	to represent the sum. This is fixed in renormalize.
;	If the 31st (MS) bit is not zero than the sum
;	mantissa will be shifted to the left and the 
;	exponent will be reduced by 1 for every shift required.
;	
;	ZERO CASES:
;		There are 2 main zero cases that need to
;		be dealt with during addition:
;
;		-When adding a number that is zero, the
;		result is simply the other operand.
;
;		-When adding a negative number to a 
;		positive number, the result can be
;		zero, which needs to be handled separately
;		as renormalize cannot handle if it is
;		passed zero. (E!=0, M=0 - causes a crash)
;
; INPUT: Passed two 32-bit IEEEf floating point numbers.
;
; CALLER OUTPUT: The 32-bit IEEE floating point result from the
;		 addition operation.
;
; ASSUMPTIONS/LIMITATIONS:
;	input parameter numbers are assumed to be valid 
;	32-bit IEEE floating point numbers.
;
; DATA STRUCTURES:
;	floatRecord (6 bytes):
;		SIGN (1 byte)
;		BIASED_EXP (1 byte)
;		MANTISSA (1 longword)	
;
; DATA REGISTERS:
;	d0 - holds elements of floatRecord1 to be compared
;	     or operated on
;
;	d1 - holds elements of floatRecord2 to be compared
;	     or operated on
;
;	d2 - used to compare signs of the 2 floatRecords
;
;	d3 - used to compare exponents of the 2 floatRecords
;
; ADDRESS REGISTERS:
;	a0 - reference to floatRecord1
;
;	a1 - reference to floatRecord2
;
;	a2 - reference to the floatRecord that contains the result
; 
; E.G. CALL:	
;	subq.l	#4,sp
;	pea	fr2		;floatRecord variable
;	pea	fr1		;floatRecord variable
;	jsr	add_FP
;	addq.l	#8,sp
;	move.l	(sp)+,sum	;sum == the result of the addition as 
;				;a 32-bit IEEE floating point number

;constants
AFP_RESULT	equ	16
AFP_OP2		equ	12
AFP_OP1		equ	8

AFP_FR1		equ	-6	;floatRecord variable (operand)
AFP_FR2		equ	-12	;floatRecord variable (operand)
AFP_FR_RESULT	equ	-18	;floatRecord variable (result)

add_FP:
	link	a6,#-18
	movem.l	d0-d3/a0-a2,-(sp)
	
afp_unpack_op1:
	pea	AFP_FR1(a6)
	move.l	AFP_OP1(a6),-(sp)
	jsr	unpackFloat
	addq.l	#8,sp

afp_unpack_op2:
	pea	AFP_FR2(a6)
	move.l	AFP_OP2(a6),-(sp)
	jsr	unpackFloat
	addq.l	#8,sp

afp_scale:
	pea	AFP_FR2(a6)
	pea	AFP_FR1(a6)
	jsr	scale
	addq.l	#8,sp

afp_addition_prep:
	lea	AFP_FR1(a6),a0
	lea	AFP_FR2(a6),a1
	lea	AFP_FR_RESULT(a6),a2

	move.l	MANTISSA(a0),d0
	move.l	MANTISSA(a1),d1

	lsr.l	#1,d0			;makes space for a 25th bit in the 
	lsr.l	#1,d1			;mantissa (represents carry out)
					;if there is one
afp_check_for_zeros:			
	cmpi.b	#0,BIASED_EXP(a0)	;check if floatRecord1 == 0
	bne	afp_fr1_not_zero
	cmpi.l	#0,MANTISSA(a0)
	bne	afp_fr1_not_zero

afp_return_fr2:				;if one operand is zero, the
	subq.l	#4,sp			;other operand can be returned
	pea	AFP_FR2(a6)		;as addition of zero doesnt
	jsr	packFloat		;affect the result
	addq.l	#4,sp
	move.l	(sp)+,AFP_RESULT(a6)
	
	bra	done_add_FP

afp_fr1_not_zero:			;check if floatRecord2 == 0
	cmpi.b	#0,BIASED_EXP(a1)
	bne	afp_signs_are_equal
	cmpi.l	#0,MANTISSA(a1)
	bne	afp_signs_are_equal

afp_return_fr1:				;if one operand is zero, the
	subq.l	#4,sp			;other operand can be returned
	pea	AFP_FR1(a6)		;as addition of zero doesnt
	jsr	packFloat		;affect the result
	addq.l	#4,sp
	move.l	(sp)+,AFP_RESULT(a6)

	bra	done_add_FP

afp_signs_are_equal:			;if signs are equal, mantissas are
	move.b	SIGN(a0),d2		;just added together
	cmp.b	SIGN(a1),d2
	bne	afp_signs_not_equal

	add.l	d0,d1

	move.b	SIGN(a0),SIGN(a2)		;the result is now ready to
	move.b	BIASED_EXP(a0),BIASED_EXP(a2)	;be renormalized
	move.l	d1,MANTISSA(a2)

	pea	AFP_FR_RESULT(a6)
	jsr	renormalize			
	addq.l	#4,sp

	subq.l	#4,sp	
	pea	AFP_FR_RESULT(a6)
	jsr	packFloat
	addq.l	#4,sp
	move.l	(sp)+,AFP_RESULT(a6)
	
	bra	done_add_FP

afp_signs_not_equal:	
	cmp.l	d1,d0			;if record1.man > record2.man
	blo	afp_fr1_is_smaller

	sub.l	d1,d0			;record1.man - record2.man
	
afp_result_zero_check1:			;checking if result == 0
	cmpi.l	#0,d0
	bne	afp_result_not_zero1
	move.b	#0,SIGN(a2)
	move.b	#0,BIASED_EXP(a2)
	move.l	#0,MANTISSA(a2)		;skips renormalize if result
	bra	afp_subtraction_done1	;is zero

afp_result_not_zero1:
	move.b	SIGN(a0),SIGN(a2)		;the result is now ready to
	move.b	BIASED_EXP(a0),BIASED_EXP(a2)	;be renormalized
	move.l	d0,MANTISSA(a2)

afp_subtraction_rn1:			;when the value of floatRecord1 >
	pea	AFP_FR_RESULT(a6)	;		   floatRecord2
	jsr	renormalize			
	addq.l	#4,sp

afp_subtraction_done1:
	subq.l	#4,sp	
	pea	AFP_FR_RESULT(a6)
	jsr	packFloat
	addq.l	#4,sp
	move.l	(sp)+,AFP_RESULT(a6)
	
	bra	done_add_FP

afp_fr1_is_smaller:
	sub.l	d0,d1			;record2.man - record1.man

afp_result_zero_check2:
	cmpi.l	#0,d1
	bne	afp_result_not_zero2
	move.b	#0,SIGN(a2)
	move.b	#0,BIASED_EXP(a2)
	move.l	#0,MANTISSA(a2)		;skips renormalize if the result
	bra	afp_subtraction_done2	;is zero

afp_result_not_zero2:
	move.b	SIGN(a1),SIGN(a2)		;the result is now ready to
	move.b	BIASED_EXP(a1),BIASED_EXP(a2)	;be renormalized
	move.l	d1,MANTISSA(a2)

afp_subtraction_rn2:			;when the value of floatRecord2 >
	pea	AFP_FR_RESULT(a6)	;		   floatRecord1
	jsr	renormalize			
	addq.l	#4,sp

afp_subtraction_done2:
	subq.l	#4,sp	
	pea	AFP_FR_RESULT(a6)
	jsr	packFloat
	addq.l	#4,sp
	move.l	(sp)+,AFP_RESULT(a6)
	
done_add_FP:
	movem.l	(sp)+,d0-d3/a0-a2
	unlk	a6	
	rts

;----- SUBROUTINE: unpackFloat -----
;
;----- void unpackFloat (float number, floatRecord *result) -----
;
; PURPOSE: Decomposes a 32-bit IEEE floating point number into its
;	   three component parts and stores each in the appropriate
;	   field in a passed floatRecord variable.
;
; DETAILS: The function decomposes the 32-bit IEEE floating point
;	   number it to its three component parts and stores each
;	   in the appropriate field in the provided floatRecord 
;	   variable.
;
; INPUT: Passed a floatRecord variable.
;
; CALLER OUTPUT: The updated floatRecord variable by reference.
;
; ASSUMPTIONS/LIMITATIONS:
;	input parameter number is assumed to be a valid 
;	32-bit IEEE floating point number.
;
; DATA STRUCTURES:
;	floatRecord (6 bytes):
;		SIGN (1 byte)
;		BIASED_EXP (1 byte)
;		MANTISSA (1 longword)		
;
; DATA REGISTERS:
;	d0 - holds the 32-bit IEEE floating point number
;
;	d1 - used to separate the components of the given IEEE number
;
; ADDRESS REGISTERS:
;	a0 - holds the passed floatRecord variable to be updated
;
; E.G. CALL:	
;	pea	result		;result is a floatRecord variable
;	move.l	number,-(sp)	;number is a 32-bit IEEE FP number
;	jsr	unpackFloat
;	addq.l	#8,sp
;

;constants
UF_NUMBER	equ	8
UF_RESULT	equ	12

unpackFloat:
	link	a6,#0
	movem.l	d0-d1/a0,-(sp)
	move.l	UF_NUMBER(a6),d0
	move.l	UF_RESULT(a6),a0

uf_check_zero:				;zero is a special case
	cmp.l	#0,d0			;if number == +0.0
	beq	uf_is_positive_zero
	cmp.l	#$80000000,d0		;if number == -0.0
	beq	uf_is_negative_zero
	bra	uf_get_mantissa

uf_is_positive_zero:
	move.b	#0,SIGN(a0)
	move.b	#0,BIASED_EXP(a0)
	move.l	#0,MANTISSA(a0)
	bra	uf_done

uf_is_negative_zero:
	move.b	#1,SIGN(a0)
	move.b	#0,BIASED_EXP(a0)
	move.l	#0,MANTISSA(a0)
	bra	uf_done

uf_get_mantissa:
	move.l	d0,d1		;separating the mantissa component
	lsl.l	#8,d1
	or.l	#$80000000,d1
	move.l	d1,MANTISSA(a0)

uf_get_sign:
	move.l	d0,d1		;separating the sign
	clr.w	d1
	rol.l	#1,d1
	move.b	d1,SIGN(a0)

uf_get_biased_exp:
	clr.b	d1
	swap.w	d1
	lsr.l	#8,d1
	move.b	d1,BIASED_EXP(a0)

uf_done:
	movem.l	(sp)+,d0-d1/a0
	unlk	a6	
	rts

;----- SUBROUTINE: packFloat -----
;
;----- float packFloat (floatRecord *result) -----
;
; PURPOSE: Takes three component values from the given floatRecord
;	   variable and composes the corresponding 32-bit floating
;	   point number.
;
; DETAILS: The function take the three component values from the
;	   given floatRecord variable and composes the 
;	   corresponding 32-bit IEEE floating point number. 
;	   This value is returned to the caller.
;
; INPUT: Passed a floatRecord variable
;
; CALLER OUTPUT: Returns a 32-bit IEEE floating point number. 
;
; ASSUMPTIONS/LIMITATIONS:
;	A floatRecord variable must be in the unpacked format
;	before being packed.
;
; DATA STRUCTURES:
;	floatRecord (6 bytes):
;		SIGN (1 byte)
;		BIASED_EXP (1 byte)
;		MANTISSA (1 longword)
;
; DATA REGISTERS:
;	d0 - used to copy the components of the given floatRecord
;
;	d1 - holds the components of the given IEEE number to copy
;
; ADDRESS REGISTERS:
;	a0 - holds the passed floatRecord variable
;
; E.G. CALL:	
;	subq.l	#4,sp
;	pea	result		;result == a floatRecord variable
;	jsr	packFloat
;	addq.l	#4,sp
;	move.l	(sp)+,p_result	:p_result holds the packed result
;

;constants
PF_RESULT	equ	8	;the passed floatRecord variable
PF_RETURN	equ	12

packFloat:
	link	a6,#0
	movem.l	d0-d1/a0,-(sp)
	move.l	PF_RESULT(a6),a0
	clr.l	d0		;mask of $00000000 to copy components
	clr.l	d1

pf_get_sign:
	move.b	SIGN(a0),d1
	ror.l	#1,d1
	or.l	d1,d0
	clr.l	d1

pf_get_biased_exp:
	move.b	BIASED_EXP(a0),d1
	lsl.w	#7,d1
	swap.w	d1
	or.l	d1,d0

pf_get_mantissa:
	move.l	MANTISSA(a0),d1
	and.l	#$7FFFFFFF,d1		;removing the hidden 1
	lsr.l	#8,d1
	or.l	d1,d0
	
	move.l	d0,PF_RETURN(a6)	;packed value is returned

pf_done:
	movem.l	(sp)+,d0-d1/a0
	unlk	a6
	rts

;----- SUBROUTINE: scale -----
;
;--- void scale (floatRecord *unpack1, floatRecord *unpack2) ---
;
; PURPOSE: Adjusts the value with the smaller exponent value, and 
;	   correspondingly the associated mantissa value, so that
;	   the two floatRecords have the same exponent value.
;
; DETAILS: The function adjusts the value with the smaller
;	   exponent value, by shifting the bits of the
;	   mantissa and incrementing the exponent for each time
;	   the bits need to be shifted. Afterwards the two 
;	   floatRecords will have the same exponent value. 
;	   The adjustments to the appropriate floatRecord variable
;	   are retained for the caller.
;
; Formulae: During scaling, if the separated biased exponent and
;	    mantissa are both equal to zero, this is a special
;	    case that indicates the value is just zero.
; 
; INPUT: Passed two floatRecord variables by reference.
;
; CALLER OUTPUT: The retained adjustments made to the appropriate
;		 floatRecord variable
;
; ASSUMPTIONS/LIMITATIONS:
;	Both passed floatRecord variables must be unpacked.
;
; DATA STRUCTURES:
;	floatRecord (6 bytes):
;		SIGN (1 byte)
;		BIASED_EXP (1 byte)
;		MANTISSA (1 longword)
;
; DATA REGISTERS:	
;	d0 - holds the the positive difference between the 
;	     exponent values
;
;	d1 - holds elements of floatRecord1 to be compared
;	     or operated on
;
;	d2 - holds elements of floatRecord2 to be compared
;	     or operated on
;
; ADDRESS REGISTERS:
;	a0 - reference to floatRecord1
;
;	a1 - reference to floatRecord2
;
; E.G. CALL:	
;	pea	fr2	;a floatRecord variable
;	pea	fr1	;a floatRecord variable
;	jsr	scale
;	addq.l	#8,sp
;

;constants
SC_FR1	equ	12		;floatRecord1 
SC_FR2	equ	8		;floatRecord2

scale:		
	link	a6,#0
	movem.l	d0-d2/a0-a1,-(sp)
	move.l	SC_FR1(a6),a0
	move.l	SC_FR2(a6),a1		
	clr.l	d0	
	
	move.b	BIASED_EXP(a0),d1	;exp of first floatRecord
	move.b	BIASED_EXP(a1),d2	;exp of second floatRecord	
	
scale_exp_equal:			;if exp are equal, no need to 
	cmp.b	d1,d2			;shift
	beq	done_scale
	
scale_check_for_bigger_exp:		;get a positive difference value
	cmp.b	d1,d2
	bhi	scale_fr2_exp_bigger
	move.b	d1,d0
	sub.b	d2,d0
	subq.l	#1,d0

	move.l	MANTISSA(a1),d2	
	cmpi.b	#24,d0			;if difference > 24 then E=0,M=0
	blo	scale_shift_fr2
	move.b	#0,BIASED_EXP(a1)	;floatRecord2 == 0 after shift		
	move.l	#0,MANTISSA(a1)
	
	bra	done_scale

scale_shift_fr2:			;while (difference > 0)
	lsr.l	#1,d2			;shift mantissa to the right
	addq.b	#1,BIASED_EXP(a1)
	dbra	d0,scale_shift_fr2
	move.l	d2,MANTISSA(a1)
	
	bra 	done_scale

scale_fr2_exp_bigger:
	move.b	d2,d0
	sub.b	d1,d0
	subq.b	#1,d0

	move.l	MANTISSA(a0),d1
	cmpi.b	#24,d0			;if difference > 24 then E=0,M=0
	blo	scale_shift_fr1
	move.b	#0,BIASED_EXP(a0)	;floatRecord1 == 0 after shift
	move.l	#0,MANTISSA(a0)

	bra	done_scale

scale_shift_fr1:
	lsr.l	#1,d1			;while (difference > 0)
	addq.b	#1,BIASED_EXP(a0)
	dbra	d0,scale_shift_fr1	;shift mantissa to the right
	move.l	d1,MANTISSA(a0)
	
done_scale:
	movem.l	(sp)+,d0-d2/a0-a1
	unlk	a6
	rts

;----- SUBROUTINE: renormalize -----
;
;----- void renormalize (floatRecord *result) -----
;
; PURPOSE:The normalized status of the received floatRecord is 
;	   unknown, but the function will, if needed, renormalize
;	   the given floatRecord values.
;
; DETAILS: Whether a received floatRecord is normalized or not is
;	   determined by whether or not there is a carry out 
;	   during addition, or whether the leading bit of the
;	   mantissa is no longer a 1 after addition.
;
;	   In add_FP the mantissa is shifted to create space for a
;	   25th bit in front of the mantissa value and if it
;	   contains a 1 after addition this is assumed to mean
;	   a carry out has occured and is dealt with by 
;	   incrementing the exponent and chopping off the least
;	   significant bit of the mantissa.
;
;	   In the case that the mantissa has a 0 in its MSbit, then
;	   the exponent of the floatRecord variable is decremented
;	   and the mantissa is shifted to the left by 1 bit and this
;	   is repeated until the MSbit contains a leading 1.
;
; INPUT: Passed a floatRecord variable by reference.
;
; CALLER OUTPUT: The passed floatRecord variable will be
;	         renormalized if need and changes are 
;	         retained for the caller.
;
; ASSUMPTIONS/LIMITATIONS:
;	renormalize cannot properly handle biased exponents and 
;	mantissas that indicate: denormalized numbers, + or -
;	infinity, or NaN (not a number).
;
; DATA STRUCTURES:
;	floatRecord (6 bytes):
;		SIGN (1 byte)
;		BIASED_EXP (1 byte)
;		MANTISSA (1 longword)
;
; DATA REGISTERS:	
;	d0 - holds the mantissa of the passed floatRecord that
;	     may need to be normalized
;
; ADDRESS REGISTERS:
;	a0 - reference to the passed floatRecord
;
; E.G. CALL:	
;	pea	fr		;a floatRecord variable
;	jsr	renormalize
;	addq.l	#4,sp
;

;constants
RN_FR	equ	8

renormalize:		
	link	a6,#0
	movem.l	d0/a0,-(sp)
	move.l	RN_FR(a6),a0
	move.l	MANTISSA(a0),d0

rn_check_carry_bit:
	btst.l	#31,d0
	beq	rn_no_carry_bit
	and.l	#$FFFFFF00,d0		;clearing the excess bits	
	move.l	d0,MANTISSA(a0)
	addq.b	#1,BIASED_EXP(a0)	;if a carry out of addition
	bra	done_renormalize	;occurs, our biased exponent
					;should be increased by 1
rn_no_carry_bit:
	lsl.l	#1,d0			;removing the extra 25th bit 
					;used to indicate carry bit
rn_shift_left:			
	btst.l	#31,d0			;if the MS bit is 0, shift left
	bne	rn_done_shift		;until a leading 1 is reached
	lsl.l	#1,d0
	subq.b	#1,BIASED_EXP(a0)	;everytime the mantissa needs
	bra	rn_shift_left		;to be shifted left, reduce
					;the exponent by 1
rn_done_shift:
	and.l	#$FFFFFF00,d0
	move.l	d0,MANTISSA(a0)

done_renormalize:
	movem.l	(sp)+,d0/a0
	unlk	a6
	rts

;----- SUBROUTINE: printCstring -----
;
;----- void printCstring (char string[]) -----
;
; PURPOSE: Outputs a string to the screen with no formatting included.
;
; DETAILS: Outputs the received string to the screen; no formatting done,
; 	   i.e. newline, etc., unless the string contains formatting 
;	   characters.
;
; CALLER OUTPUT: The given string printed to the console screen
;
; INPUT: A passed C-string.
;
; ASSUMPTIONS/LIMITATIONS:
;	Passed string must be null-terminated, a C-string. Byte counted
;	strings will not be printed properly.
;
; DATA REGISTERS:	
;	d0 - holds a single character to be written to the screen
;
; ADDRESS REGISTERS:
;	a0 - holds the C string to be output to the screen
; 
; E.G. CALL:	
;	pea	string		;where string is a C-string
;	jsr	printCstring
;	addq.l	#4,sp		
;

;constants
C_STRING	equ	8

printCstring:		
	link	a6,#0
	movem.l	d0-d2/a0-a2,-(sp)
	move.l	C_STRING(a6),a0
	clr.w	d0

printCstring_loop:			;prints a null terminated string
	move.b	(a0)+,d0
	beq	done_printCstring
	move.w	d0,-(sp)
	jsr	write_char
	addq.l	#2,sp
	bra	printCstring_loop

done_printCstring:
	movem.l	(sp)+,d0-d2/a0-a2
	unlk	a6
	rts

;----- SUBROUTINE: hex2string -----
;
;----- void hex2string (float number, char string[]) -----
;
; PURPOSE: Converts a given 32-bit IEEE floating point number to
; 	   its corresponding hexadecimal characters to output
;	   to the screen.
;
; DETAILS: Each digit of the number is converted into the 
;	   corresponding character and stored in the string, in
;	   the same order as the original number. The string will
;	   be null-terminated.
;
; INPUT: Passed a 32-bit IEEE floating point number and an
;	 empty array of type char (string) to be filled.
;
; CALLER OUTPUT: A null-terminated string of characters
;		 representing the given value in hexadecimal
;		 in the same order as the original number in 
;		 the passed char array (string).
;
; ASSUMPTIONS/LIMITATIONS:
;	char string [] must be atleast 9 bytes in size.
;	This function will not work for any size other
;	than 32-bit values.
;
; DATA REGISTERS:	
;	d0 - holds half of the 32-bit number 
;
;	d1 - holds half of the 32-bit number
;
;	d2 - loop counter for copying the numbers to the string
;	   - used for comparisons of each digit in the string
; 
;	d3 - loop counter for checking digits
;
; ADDRESS REGISTERS:
;	a0 - holds the string that should be modified to contain
;	     the IEEE floating point number in hex characters 
;
; E.G. CALL:	
;	pea	string		;string is a null-terminated string
;	move.l	number,-(sp)	;number == a floating point longword
;	jsr	hex2string
;	addq.l	#8,sp
;

;constants
H2S_STRING	equ	12
H2S_NUMBER	equ	8

hex2string:	
	link	a6,#0
	movem.l	d0-d3/a0,-(sp)	

	move.l	H2S_STRING(a6),a0
	move.l	H2S_NUMBER(a6),d0	;splitting up the number to
	move.l	H2S_NUMBER(a6),d1	;separate into groups of 4
	and.l	#$0f0f0f0f,d0		;bits
	and.l	#$f0f0f0f0,d1	
	move.w	#3,d2			;loop counter
	adda.l	#9,a0
	move.b	#NULL,-(a0)	

h2s_copy:			;copying each digit into the
	move.b	d0,-(a0)	;provided string
	lsr.l	#8,d0
	lsr.l	#4,d1
	move.b	d1,-(a0)
	lsr.l	#4,d1
	dbra	d2,h2s_copy

h2s_done_copy:
	move.w	#7,d3			;loop counter
	
h2s_check_digit:
	move.b	(a0),d2		;digits are checked/converted 8 times
	
	cmp.b	#10,d2
	bne	h2s_not_A
	move.b	#'A',(a0)+	;10 == 'A' in hex
	bra	h2s_digit_found	

h2s_not_A:
	cmp.b	#11,d2
	bne	h2s_not_B
	move.b	#'B',(a0)+	;11 == 'B' in hex
	bra	h2s_digit_found

h2s_not_B:
	cmp.b	#12,d2
	bne	h2s_not_C
	move.b	#'C',(a0)+	;12 == 'C' in hex
	bra	h2s_digit_found	

h2s_not_C:
	cmp.b	#13,d2
	bne	h2s_not_D
	move.b	#'D',(a0)+	;13 == 'D' in hex
	bra	h2s_digit_found

h2s_not_D:
	cmp.b	#14,d2
	bne	h2s_not_E
	move.b	#'E',(a0)+	;14 == 'E' in hex
	bra	h2s_digit_found

h2s_not_E:
	cmp.b	#15,d2
	bne	h2s_not_a_letter
	move.b	#'F',(a0)+	;15 == 'F' in hex
	bra	h2s_digit_found

h2s_not_a_letter:
	add.b	#'0',(a0)+		;converting numbers to their ascii
					;character value
h2s_digit_found:			
	dbra	d3,h2s_check_digit		

done_hex2string:
	movem.l	(sp)+,d0-d3/a0
	unlk	a6
	rts

;----- SUBROUTINE: write_char -----
;
; PURPOSE: writes a character to the screen.
;
; E.G. CALL:
;	move.w	char,-(sp)
;	jsr	write_char
;	addq.l	#2,sp

;constants
WC_CHAR		equ	8

write_char:
	link	a6,#0
	movem.l	d0-d2/a0-a2,-(sp)
	
	move.w	WC_CHAR(a6),-(sp)
	move.w	#c_conout,-(sp)
	trap	#GEMDOS
	addq.l	#4,sp
	
	movem.l	(sp)+,d0-d2/a0-a2
	unlk	a6
	rts

;----- SUBROUTINE: exit -----
;
; PURPOSE: terminates the program.  This routine never returns.

exit:		clr.w	-(sp)
		trap	#1






