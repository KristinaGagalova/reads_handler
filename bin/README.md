## Useful commands for read files handling

Count the number of lines in each file, to see if the concat is as expected (in parallel):
```
find . -type f -name "*.gz" | parallel -j $(nproc) "echo {#}: {}; zcat '{}' | wc -l"
```
