# pg_cpu_load_tester
This repo is about doing some load testing on Postgres.
The idea is to compare
* running statements with and without transaction control
* empty transactions vs a simple query (select 1) a table read, and a table write
* running workload on identical hardware, increasing the number of cpu's
* writing temp tables vs writing real tables

The repo contains some bash scripts, a Docker file, and a testprogram written in GoLang and later rewritten in rust.
