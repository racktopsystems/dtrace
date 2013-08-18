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
data analysis software like R, Matlab, etc. The output is comma separated to ease
the loading of the data into analytics tools. Within RackTop we use this tool
quite commonly to get some sense from customer systems about what their disks are
doing. Warning!!! If the system has a large number of disks, more than a couple,
this script will return large amounts of information, potentially hundreds of 
thousands if not millions of lines in a relatively short amount of time. It is best
to send stdout from this script into a file instead of to screen.
*/

dtrace:::BEGIN
{
    printf("Tracing... Hit Ctrl-C to end.\n");
    printf("timestamp,operation,device,totalbytes\n");
}

io:::start
 /args[1]->dev_name != "nfs"/ /* We do not want to catch any NFS traffic. */
{
    start_time[args[0]->b_blkno] = timestamp;
    /* Storing buffer size to make sure that io:::done probes are triggered
    only when this value is greater than 0 */
    trig = args[0]->b_bufsize;
}

io:::done
/(args[0]->b_flags & B_READ) && (this->start = start_time[args[0]->b_blkno]) && trig > 0/
{
	this->size = args[0]->b_bcount;
    this->delta = (timestamp - this->start) / 1000;
    /* @avgIO[(walltimestamp / 1000000000), 
        "READ", args[1]->dev_statname, this->size] = avg(this->delta); */
    @sumIO[(walltimestamp / 1000000000), 
        "READ", args[1]->dev_statname] = sum(this->size);
    /* Figure out average byte size */
    @bsize["average READ, bytes"] = avg(this->size);
    @latencyUS["READ I/O, us"] = quantize(this->delta);
    @avgs["average READ I/O, us"] = avg(this->delta); 
    start_time[args[0]->b_blkno] = 0;
    trig = 0;
}

io:::done
/!(args[0]->b_flags & B_READ) && (this->start = start_time[args[0]->b_blkno]) && trig > 0/
{
	this->size = args[0]->b_bcount;
    this->delta = (timestamp - this->start) / 1000;
    /* @avgIO[(walltimestamp / 1000000000), 
        "WRITE", args[1]->dev_statname, this->size] = avg(this->delta); */
    @sumIO[(walltimestamp / 1000000000),
        "WRITE", args[1]->dev_statname] = sum(this->size);
    /* Figure out average byte size */
    @bsize["average WRITE, bytes"] = avg(this->size);
    @latencyUS["WRITE I/O, us"] = quantize(this->delta);
    @avgs["average WRITE I/O, us"] = avg(this->delta); 
    start_time[args[0]->b_blkno] = 0;
    trig = 0;
}

:::tick-1sec
{ /* Every 1 seconds we print one or more lines for each disk 
	giving a summary of the IO, one line per type of IO, i.e. Read/Write. */
	printa("%d,%s,%s,%@d\n", @sumIO);
	trunc(@sumIO);
}

dtrace:::END
{ /* Summary printed at the end, when control-c is entered, 
	for human consumption. */
    printf("\nI/O completed time and size summary:\n\n");
    printa("\t%s     %@d\n", @avgs);
    printa("\t%s     %@d\n", @bsize);
    printa("\n   %s\n%@d\n", @latencyUS);
}