#!/usr/sbin/dtrace -s
#pragma D option quiet
/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 *
 * Copyright (c) 2014, RackTop Systems.
 * Use is subject to license terms.
 *
 * Credits:
 * Brendan Gregg, as always, borrowed a bit from one of his great one-liners.
 *
 * Description:
 * Sript prints out iscsi operations by client and IQN, and returns
 * size of the OP, whether send or recieve, bytes and how many of those
 * per second.
 *
 */


dtrace:::BEGIN
{
    printf("%-18s %-44s %-4s %-8s %-6s\n", "CLIENT (IP)", "CLIENT (IQN)", "OP",
        "BYTES", "COUNT");
}

iscsi:::data-send
{
    @x[args[0]->ci_remote, args[1]->ii_initiator, "SEND", args[1]->ii_datalen] = count();

}


iscsi:::data-receive
{
    @x[args[0]->ci_remote, args[1]->ii_initiator, "RECV", args[1]->ii_datalen] = count();
}

tick-1sec {
    printa("%-18s %-44s %-4s %-8d %@-6d\n", @x);
    trunc(@x);
}