/*
Package pg_cpu_load is a self-contained Go program which tries to bring Postgres load
to the max, the cpu;s can handle. It just runs the simplest queries one can think of.
This is mainly to test if there is any correlation between the number of CPU;s and the maximum TPS.
*/

    package main

    import (
        "database/sql"

        "github.com/lib/pq"

        "log"
        "time"
        "strconv"
        "flag"
    )

    func avg(x []float64) float64 {
        var total float64 = 0
        for _, value:= range x {
            total += value
        }
        return (total/float64(len(x)))
    }

    func handle_sql_error(err error) {
        if err != nil {
            if pqerr, ok := err.(*pq.Error); ok {
                log.Output(1, "pq error:" + pqerr.Code.Name())
            } else {
                panic(err)
            }
        }
    }

    func thread(id int, total int, threadspeed chan float64, wait_sec int, ttype int) {
        var conninfo string = ""
        var stmt *sql.Stmt
        var rows *sql.Rows
        var err error
        var tx *sql.Tx

        db, err := sql.Open("postgres", conninfo)
        if err != nil {
            panic(err)
        }
        defer db.Close()
        if ttype == 1 {
            stmt, err = db.Prepare("SELECT 1")
            handle_sql_error(err)
        }

        num_transactions := 1000
        for {
            start := time.Now()
            for i := 0; i < num_transactions; i++ {
                if ttype == 0 {
                    tx, err = db.Begin()
                    handle_sql_error(err)
                    err = tx.Commit()
                    handle_sql_error(err)
                } else if ttype == 1 {
                    _, err = stmt.Exec()
                    handle_sql_error(err)
                } else if ttype == 2 {
                    rows, err = db.Query("SELECT 1")
                    handle_sql_error(err)
                    rows.Close()
                }
            }
            delta := time.Since(start)
            tps := float64(num_transactions)/delta.Seconds()
            num_transactions = int(tps * float64(wait_sec))
            threadspeed <- tps
        }
    }

    func main() {
        count := flag.Int("c", 4294967295, "How much runs would you like")
        parallel := flag.Int("p", 10, "How much parallel sessions")
        freq := flag.Int("f", 1, "How much seconds for one run")
        ttype := flag.Int("t", 0, "Transaction type. 0: empty, 1: Prepared simple, 2: Simple") //, 3: Prepared read, 4: Read, 5: Prepared write, 6: Write")
        flag.Parse()

        if *parallel <= 0 {
            panic("parallel setting must be >0.")
        } else if *freq <= 0 {
            panic("Seconds / run setting must be >0.")
        } else if *ttype < 0 || *ttype > 2 {
            panic("Transaction type must be between 0 and 2")
        }
        threadspeed := make(chan float64)
        speedlist := make([]float64, *parallel)
        for i := 0; i < *parallel; i++ {
            go thread(i, *parallel, threadspeed, *freq, *ttype)
        }
        for j := 0; j < *count; j++ {
            for i := 0; i < *parallel; i++ {
                speedlist[i] = <-threadspeed
            }
            avgspeed := avg(speedlist)
            totalspeed := avgspeed * float64(*parallel)
            log.Output(1, "TPS: " + strconv.FormatFloat(totalspeed, 'f', 6, 64))
        }
    }
