grep PCL_PARALLEL ../logs/*/env | sed 's/\/env:.*=/ /' | while read l; do ln -sf $l; done
find -L . -name 'pg_cpu_load_*' | while read f; do echo -n "$f:"; awk '/Total tps:/{a+=$3;b+=1}END{print(a/b)}' $f; done | sed 's/\.\///;s/\.log//;s/[/:]/ /g;s/pg_cpu_load_//' | awk '{printf("%-35s %3s %7.1f\n",$2,$1,$3)}' | LC_ALL=c sort
