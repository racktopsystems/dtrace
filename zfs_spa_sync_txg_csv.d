#!/usr/sbin/dtrace -s
#pragma D option quiet
/*
The MIT License (MIT)

Copyright (c) 2013 RackTop Systems

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Description:
------------
This script is mainly useful for collection of data which is later plugged into
data analysis software like R, Matlab, etc. The output is comma separated to
ease the loading of the data into analytics tools. Variations of this tool exist
in many forms already. The point of this variant is to report time and amount of
IO by txg group. It is useful to know how long spa_sync events take, and
by breaking them down by txg and spa name one can get a sense for where most of
the IO is going, and generally what size of each transaction is by spa (pool).
*/

inline int SYNCING = 1;
inline int CONVERT_MS = 1000000;
inline int MB = 1 << 20;
inline int CONVERT_S = 1000000000;
inline int IGNORE = -1; /* If function returns almost immediately ignore it! */

BEGIN{
    printf("%s,%s,%s,%s,%s,%s,%s\n",
    "pool", "txg", "min", "max", "avg", "size_MB","count");
}

::spa_sync:entry {
    self->txg = args[0]->spa_syncing_txg;
    self->x = (char *)args[0]->spa_name;
    self->start = timestamp;
    in_spa_sync[self->txg] = SYNCING;
    spa_name = self->x;
    txg = self->txg;
}

io:::start
/in_spa_sync[txg] && args[0]->b_flags & B_WRITE /
{
    @io[stringof(spa_name), txg] = count();
    @bytes[stringof(spa_name), txg] = sum(args[0]->b_bcount);
}

::spa_sync:return /in_spa_sync[txg] > 0/ {
    this->ms = ((timestamp - self->start) / CONVERT_MS);
    @min[stringof(self->x), self->txg] = min(this->ms ? this->ms > 0 : IGNORE);
    @max[stringof(self->x), self->txg] = max(this->ms);
    @avg[stringof(self->x), self->txg] = avg(this->ms);
}

::spa_sync:return /in_spa_sync[txg]/ {
    in_spa_sync[txg] = 0;
    self->start = 0;
    self->txg = 0;
}

tick-5sec {
    normalize(@bytes, MB);
    printa("%s,%d,%@d,%@d,%@d,%@d,%@d\n", @min, @max, @avg, @bytes, @io);
    trunc(@min);
    trunc(@max);
    trunc(@avg);
    trunc(@bytes);
    trunc(@io);
}
