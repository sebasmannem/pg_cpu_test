# pg_cpu_load_tester

## General information
This repo is about doing some load testing on Postgres.
The idea is to compare
* running statements with and without transaction control
* empty transactions vs a simple query (select 1) a table read, and a table write
* running workload on identical hardware, increasing the number of cpu's
* writing temp tables vs writing real tables

The repo contains some bash scripts, a Docker file, and a testprogram written in GoLang and later rewritten in rust.

## Installation
* Download this folder to your test system
* cd into the pg_cpu_load_tester folder
* Build the Docker container with `docker build --rm -t pg_cpu_load_tester .`
* Change run_tests.sh as you see fit
  * Maybe choose better values for PCL_PARALLEL
  * Maybe choose better values for PCL_TYPES
  * Maybe choose better values for PCL_MODES
    * values can be any combination of direct, prepared, transactional, and prepared_transactional
* export a value for PCL_SYSTEMNAME (short name to identify this system, like mac_sebas, or gcp_n16)
* Run ./run_tests.sh inside a screen session
* Wait for all tests to finish
  * which takes about
    * { PCL_NUMSEC } seconds *
    * { number of PCL_MODES} *
    * { number of PCL_TYPES } *
    * { number of PCL_PARALLEL }.
  * Current setting should take about 26 hours and 40 minutes
* You can summarize the data
  * with `find "logs.${PCL_SYSTEMNAME}" -name pg_cpu_load*.log | xargs ./svg_plotter.py`
  * which will output average numbers and create svg images of very run
