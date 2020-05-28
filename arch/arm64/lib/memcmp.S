/*
 * Copyright (c) 2017 ARM Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the company may not be used to endorse or promote
 *    products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY ARM LTD ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL ARM LTD BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/* Assumptions:
 *
 * ARMv8-a, AArch64, unaligned accesses.
 */

/* includes here */
#include <linux/linkage.h>
#include <asm/assembler.h>

/* Parameters and result.  */
#define src1		x0
#define src2		x1
#define limit		x2
#define result		w0

/* Internal variables.  */
#define data1		x3
#define data1w		w3
#define data2		x4
#define data2w		w4
#define tmp1		x5

/* Small inputs of less than 8 bytes are handled separately.  This allows the
   main code to be sped up using unaligned loads since there are now at least
   8 bytes to be compared.  If the first 8 bytes are equal, align src1.
   This ensures each iteration does at most one unaligned access even if both
   src1 and src2 are unaligned, and mutually aligned inputs behave as if
   aligned.  After the main loop, process the last 8 bytes using unaligned
   accesses.  */

.p2align 6
WEAK(memcmp)
	subs	limit, limit, 8
	b.lo	.Lless8

	/* Limit >= 8, so check first 8 bytes using unaligned loads.  */
	ldr	data1, [src1], 8
	ldr	data2, [src2], 8
	and	tmp1, src1, 7
	add	limit, limit, tmp1
	cmp	data1, data2
	bne	.Lreturn

	/* Align src1 and adjust src2 with bytes not yet done.  */
	sub	src1, src1, tmp1
	sub	src2, src2, tmp1

	subs	limit, limit, 8
	b.ls	.Llast_bytes

	/* Loop performing 8 bytes per iteration using aligned src1.
	   Limit is pre-decremented by 8 and must be larger than zero.
	   Exit if <= 8 bytes left to do or if the data is not equal.  */
	.p2align 4
.Lloop8:
	ldr	data1, [src1], 8
	ldr	data2, [src2], 8
	subs	limit, limit, 8
	ccmp	data1, data2, 0, hi  /* NZCV = 0b0000.  */
	b.eq	.Lloop8

	cmp	data1, data2
	bne	.Lreturn

	/* Compare last 1-8 bytes using unaligned access.  */
.Llast_bytes:
	ldr	data1, [src1, limit]
	ldr	data2, [src2, limit]

	/* Compare data bytes and set return value to 0, -1 or 1.  */
.Lreturn:
#ifndef __AARCH64EB__
	rev	data1, data1
	rev	data2, data2
#endif
	cmp     data1, data2
.Lret_eq:
	cset	result, ne
	cneg	result, result, lo
        ret

	.p2align 4
	/* Compare up to 8 bytes.  Limit is [-8..-1].  */
.Lless8:
	adds	limit, limit, 4
	b.lo	.Lless4
	ldr	data1w, [src1], 4
	ldr	data2w, [src2], 4
	cmp	data1w, data2w
	b.ne	.Lreturn
	sub	limit, limit, 4
.Lless4:
	adds	limit, limit, 4
	beq	.Lret_eq
.Lbyte_loop:
	ldrb	data1w, [src1], 1
	ldrb	data2w, [src2], 1
	subs	limit, limit, 1
	ccmp	data1w, data2w, 0, ne	/* NZCV = 0b0000.  */
	b.eq	.Lbyte_loop
	sub	result, data1w, data2w
	ret
data1		.req	x3
data1w		.req	w3
data2		.req	x4
data2w		.req	w4
has_nul		.req	x5
diff		.req	x6
endloop		.req	x7
tmp1		.req	x8
tmp2		.req	x9
tmp3		.req	x10
pos		.req	x11
limit_wd	.req	x12
mask		.req	x13

WEAK(memcmp)
	cbz	limit, .Lret0
	eor	tmp1, src1, src2
	tst	tmp1, #7
	b.ne	.Lmisaligned8
	ands	tmp1, src1, #7
	b.ne	.Lmutual_align
	sub	limit_wd, limit, #1 /* limit != 0, so no underflow.  */
	lsr	limit_wd, limit_wd, #3 /* Convert to Dwords.  */
	/*
	* The input source addresses are at alignment boundary.
	* Directly compare eight bytes each time.
	*/
.Lloop_aligned:
	ldr	data1, [src1], #8
	ldr	data2, [src2], #8
.Lstart_realigned:
	subs	limit_wd, limit_wd, #1
	eor	diff, data1, data2	/* Non-zero if differences found.  */
	csinv	endloop, diff, xzr, cs	/* Last Dword or differences.  */
	cbz	endloop, .Lloop_aligned

	/* Not reached the limit, must have found a diff.  */
	tbz	limit_wd, #63, .Lnot_limit

	/* Limit % 8 == 0 => the diff is in the last 8 bytes. */
	ands	limit, limit, #7
	b.eq	.Lnot_limit
	/*
	* The remained bytes less than 8. It is needed to extract valid data
	* from last eight bytes of the intended memory range.
	*/
	lsl	limit, limit, #3	/* bytes-> bits.  */
	mov	mask, #~0
CPU_BE( lsr	mask, mask, limit )
CPU_LE( lsl	mask, mask, limit )
	bic	data1, data1, mask
	bic	data2, data2, mask

	orr	diff, diff, mask
	b	.Lnot_limit

.Lmutual_align:
	/*
	* Sources are mutually aligned, but are not currently at an
	* alignment boundary. Round down the addresses and then mask off
	* the bytes that precede the start point.
	*/
	bic	src1, src1, #7
	bic	src2, src2, #7
	ldr	data1, [src1], #8
	ldr	data2, [src2], #8
	/*
	* We can not add limit with alignment offset(tmp1) here. Since the
	* addition probably make the limit overflown.
	*/
	sub	limit_wd, limit, #1/*limit != 0, so no underflow.*/
	and	tmp3, limit_wd, #7
	lsr	limit_wd, limit_wd, #3
	add	tmp3, tmp3, tmp1
	add	limit_wd, limit_wd, tmp3, lsr #3
	add	limit, limit, tmp1/* Adjust the limit for the extra.  */

	lsl	tmp1, tmp1, #3/* Bytes beyond alignment -> bits.*/
	neg	tmp1, tmp1/* Bits to alignment -64.  */
	mov	tmp2, #~0
	/*mask off the non-intended bytes before the start address.*/
CPU_BE( lsl	tmp2, tmp2, tmp1 )/*Big-endian.Early bytes are at MSB*/
	/* Little-endian.  Early bytes are at LSB.  */
CPU_LE( lsr	tmp2, tmp2, tmp1 )

	orr	data1, data1, tmp2
	orr	data2, data2, tmp2
	b	.Lstart_realigned

	/*src1 and src2 have different alignment offset.*/
.Lmisaligned8:
	cmp	limit, #8
	b.lo	.Ltiny8proc /*limit < 8: compare byte by byte*/

	and	tmp1, src1, #7
	neg	tmp1, tmp1
	add	tmp1, tmp1, #8/*valid length in the first 8 bytes of src1*/
	and	tmp2, src2, #7
	neg	tmp2, tmp2
	add	tmp2, tmp2, #8/*valid length in the first 8 bytes of src2*/
	subs	tmp3, tmp1, tmp2
	csel	pos, tmp1, tmp2, hi /*Choose the maximum.*/

	sub	limit, limit, pos
	/*compare the proceeding bytes in the first 8 byte segment.*/
.Ltinycmp:
	ldrb	data1w, [src1], #1
	ldrb	data2w, [src2], #1
	subs	pos, pos, #1
	ccmp	data1w, data2w, #0, ne  /* NZCV = 0b0000.  */
	b.eq	.Ltinycmp
	cbnz	pos, 1f /*diff occurred before the last byte.*/
ENDPIPROC(memcmp)
