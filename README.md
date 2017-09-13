# tsvst

General common format:

datetime\tnode\treading\tresource\taction\tvalue

Generally no aggregation unless noted.

## logstats.pl

log stat extracter, simple state machine.

For example, 500 MB merged for a forest:

2017-01-25 09:24:39 test1 Forest-content-2-r1 merged_mb 500

To generate logstats.tsv test results file:

./logstats.pl --file test1,test2 

Extras, aggregated per minute(?) : to note

## pmapper.pl

extract some stats from pmap output

reports rounded to MB

--min gives minimum reported (default = 0)
--node gives value to output in node column

redirect output via shell

outputs complete total, regardless of min setting

For example, node n1's total memory at a datetime:

2017-09-01 15:03:10     n1      pmap_mb memory  total   1391391273228
