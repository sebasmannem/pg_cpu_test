#docker build --rm -t pg_cpu_load_tester .
#docker run pg_cpu_load_tester

FROM centos:7
#sudo and iproute for ansible readyness
COPY builder.sh run.sh pg_cpu_load_c7 loaddisplay.py /
RUN chmod 0700 /builder.sh ; /builder.sh
CMD /bin/bash /run.sh
