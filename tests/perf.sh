#!/usr/bin/env bash

PORT=${PORT:-3000}
COUNT=1000
RUNNERS=4

cd "${0%/*}"

TESTDIR="${0%/*}"

# only perf testing the todo example for now

setup() {
    cd ../examples/todo-list
    strace --follow-forks -c -o $TESTDIR/todo-list bash -c "./start.sh 2>&1 > $TESTDIR/todo.$$.output"
}

setup &
TESTPID=$!

# wait for the server to startup
RC=1
while [ $RC -ne 0 ]; do
    curl -s http://localhost:${PORT} 2>&1 # > /dev/null
    RC=$?
    echo "RC is $RC"
done

runner() {
    # now we get to test a ton :)
    for i in $(seq 1 $COUNT); do
        # first, we create the list item
        OUTPUT=$(curl -s -X PUT http://localhost:${PORT}/list -d "task=item $i")
        if [[ $? -ne 0 ]]; then
            echo "Request $i failed!"
        fi

        # parse the output to find the UUID that we care about
        ID=$(echo $OUTPUT | sed -n 's/.*hx-vals='\''{"item": "\([[:alnum:]-]*\)"}'\''>.*/\1/p')
        echo "ID was $ID. Deleting..."

        # then we delete the list item
        curl -s -X DELETE http://localhost:${PORT}/list -d "item=$ID"
    done
}

WORKERS=""
for t in $(seq 1 $RUNNERS); do
    runner > /dev/null &
    WORKERS="$WORKERS $!"
done

wait $WORKERS
pkill strace # ?
pkill -P $TESTPID
