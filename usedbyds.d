#!/usr/sbin/dtrace -s
/*
 * usedbyds.d Determine amount of space used during sampling period.
 * Min, Max and average are given for each dataset touched while
 * script was running.
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
 * Copyright (c) 2014 RackTop Systems, All rights reserved.
 * Copyright (c) 2014 Sam Zaydel, All rights reserved.
 *
 * Credits:
 * Some of these bits borrowed from Kirill Davydychev's excellent zfsio.d script.
 *
 * Description:
 * For every dataset that is in any way changed while this script is active
 * We collect average, min and max amount of used space. This includes dataset
 * and its dependents. If this is a leaf dataset, we count both it and any snapshots
 * used by it.
 */
#pragma D option dynvarsize=2M
#pragma D option quiet

BEGIN
{
    printf("Tracing... Hit Ctrl-C to end.\n\n");
    self->ts = walltimestamp;
}

::dmu_buf_hold_array_by_dnode:entry
/ args[0]->dn_objset->os_dsl_dataset /
{
    this->ds = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_myname);
    this->parent = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_parent->dd_myname);
    this->p = strjoin(strjoin(this->parent,"/"),this->ds);
    this->used = (uint64_t)args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_phys->dd_used_bytes;
    @avg[this->p] = avg(this->used);
    @min[this->p] = min(this->used);
    @max[this->p] = max(this->used);
}

END
{
    this->duration = (walltimestamp - self->ts) / 1000000; /* milliseconds */
    printf("%-40s %-18s %-18s %-18s\n", "Dataset", "AVG Used(bytes)", "MAX Used(bytes)", "MIN Used(bytes)" );
    printf("%-40s %-18s %-18s %-18s\n", "-------", "---------------", "---------------", "---------------" );
    printa("%-40s %-18@d %-18@d %-18@d\n", @avg, @max, @min);
    printf("Sample Period(ms): %-8d\n", this->duration);
}