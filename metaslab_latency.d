#!/usr/sbin/dtrace -s
/*
 * metaslab_latency.d	Show ZFS metaslab allocation latency.
 *
 * ZFS metaslab allocation occurs when space is needed to store data.
 * With time and pool fragmentation of data and space, especially on filling
 * pools this latency can increase significantly.
 * This script will provide insight into the amount of time it takes to
 * allocate metaslabs. A comparison between time on CPU and real time if
 * given, which allows us to determine whether allocation takes a long time 
 * because CPU is busy or if the functions do in fact spend a long time on
 * CPU.
 *
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License, Version 1.0 only
 * (the "License").  You may not use this file except in compliance
 * with the License.
 *
 * You can obtain a copy of the license at http://smartos.org/CDDL
 *
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file.
 *
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 *
 * Copyright (c) 2012 RackTop Systems, All rights reserved.
 * Copyright (c) 2012 Sam Zaydel, All rights reserved.
 *
 * USAGE: metaslab_latency.d <Poolname>
 *
 */

#pragma D option quiet
#pragma D option dynvarsize=4m

BEGIN 
{

	printf("Tracing... Hit Ctrl-C to end. Interval is 5 seconds.\n");
	pool=$$1;
}

::metaslab_alloc:entry 
{ 
	self->psize = args[2]; 
	self->ts = timestamp;
	self->vts = vtimestamp;
	self->spa = stringof(args[0]->spa_name); 
}

::metaslab_alloc:return / self->ts && self->spa == $$1 / 
{
	this->elapsed = (timestamp - self->ts) / 1000; 
	this->velapsed = (vtimestamp - self->vts) / 1000;
	@ds["Time real(us):"] = lquantize(this->elapsed,0,50,5); /* We split up graphs by allocation size. */
	@dsonCPU["Time onCPU(us):"] = lquantize(this->velapsed,0,50,5);
}

tick-5sec
{
/*	printa("        Time(us):                        Alloc. Size (b): %d %@d",@ds); 
	printa("        Time on-CPU(us):                 Alloc. Size (b): %d %@d",@dsonCPU); 
*/
	printa("%20s %@d\n", @ds);
	printa("%20s %@d\n", @dsonCPU);
	trunc(@ds); trunc(@dsonCPU);
	self->ts = 0; self->vts = 0;
}