#!/usr/sbin/dtrace -Cs
#pragma D option quiet
/*
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
 * Copyright (c) 2012 Joyent Inc., All rights reserved.
 * Copyright (c) 2012 Brendan Gregg, All rights reserved.
 * Copyright (c) 2014 Sam Zaydel, All rights reserved.
 *
 */

/*
 * compliments of Brendan Greggnwith slight modifications to data gathering.
 * http://dtrace.org/blogs/brendan/2012/01/09/activity-of-the-zfs-arc/
 */

dtrace:::BEGIN
{
    /* printf("lbolt rate is %d Hertz.\n", `hz); */
    printf("Tracing lbolts between ARC accesses... Hit CTRL-C to stop collection...");
    ts = timestamp;
}

fbt::arc_access:entry
{
    self->ab = args[0];
    self->lbolt = args[0]->b_arc_access;
    x[ts] = 1;
}

fbt::arc_access:return
/self->lbolt/
{
    @[ self->ab->b_size, ((self->ab->b_arc_access - self->lbolt) * 1000) / `hz ] = count(); /* Convert this to milliseconds. */
    self->ab = 0;
    self->lbolt = 0;
}

dtrace:::END
/x[ts] == 1/
{
    printf("%12s %12s %10s\n", "buffer size", "age(MS)", "count");
    printa("%12d %12d %10@d\n", @);
    x[ts] = 0;
    trunc(@);

}
