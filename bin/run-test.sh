#!/bin/bash
# define a timestamp function
timestamp() {
  date +%s
}

function debug {
  if [ ! -z "$show_debug" ]; then
    echo $@
  fi
}

function setEnv {
  echo
  if [[ $env == d* ]]; then
    service_url="http://127.0.0.1:3000"
  else
    service_url="http://127.0.0.1:3000"
  fi
  echo
  echo Using service URL: $service_url
  echo
}

function wrapOutput {
  IFS='##' read -r -a array <<< "$1"
  line=0
  for element in "${array[@]}"; do
    if [[ !  -z  $element  ]]; then
      if [ $line -eq 0 ]; then
        echo `date +"%T"` "$element" | fold -w 200 -s
      else
        echo `date +"%T"` "##$element" | fold -w 200 -s
      fi
      line=$((line + 1))
    fi
  done
}

# mark the start of the test
startTime=`timestamp`
while getopts "e:t:d:v:?" OPTION
do
  case $OPTION in
    e)
      env=$OPTARG
      echo in $env
      ;;
    t)
      task=$OPTARG
      echo for $task
      ;;
    d)
      show_debug=true
      ;;
    v)
      verbose="-i"
      ;;
    ?)
      echo
      echo "Usage:"
      echo "  run-test.sh (-e env -t task -v -? help) (commands)"
      echo
      echo "-e environment.  One of: development, qa, staging, production"
      echo "-t task.  One of: system, qvu, vu"
      echo "-d debug.  Log out more debugging info"
      echo "-v verbose.  Log out response headers from the express app.  Not recommended."
      echo
      echo "To run a specific system test pass the env and grunt task associated with the test."
      echo "./run-test.sh -e production -t system"
      echo "./run-test.sh -e qa -t qvu"
      exit
      ;;
    esac
done

setEnv
# make first call to run the test and receive the name of the unique
# results file
RUN_RESULT=`curl -is $service_url/automation/$env/$task`

#start reading the log from this point
POSITION=0
# NOTE: if/when http://gruntjs.com/ changes these strings on their end we'll have to do the same here
gruntSuccessMessage="Done, without errors."
gruntAbortedMessage="Aborted due to warnings"
#NOTE: this message text lives in topperharley/Gruntfile.js so if that should change this needs to be modified too
gruntFailureMessage="Gruntfile has failed and will now exit with an error"

debug url: $service_url/automation/$env/$task


# Parse the json response by separating the value from the key
# The value is a unique file name that we set to a local variable here
filename=`echo $RUN_RESULT | sed -e 's/^.*"resultsLog"[ ]*:[ ]*"//' -e 's/".*//'`

if [ -z "$filename" ]; then
  echo "There was an unexpected response from $service_url/automation/$env/$task."
  echo "Something is wrong with the express app. If it is not responding go to xidontpanic and run the systest alias."
  exit 1
fi

# When the test is finished it will write a new file by the same name as the $filename but with '.done' extension
echo 'The test run for ++++ '`echo $env | tr '[:lower:]' '[:upper:]' `' Deployment ++++ has started'

doWork=1
doBreak=0

while [ $doWork -eq 1 ];
do

  if [ $doBreak -eq 1 ];
  then
    # fetch the results one last time to get the remainder
    GET_RESULT=`curl -s $verbose $service_url/get/$filename/$POSITION`

    if [ ! -z "$GET_RESULT" ]; then
      response=`echo $GET_RESULT | python -c 'import sys, json; print json.load(sys.stdin)["response"]'`

      # This would be better if $response was passed but for some reason that doesn't work.
      wrapOutput "$GET_RESULT"
    fi

    # Mark the end of the test
    endTime=`timestamp`
    diff=$(($endTime-$startTime))
    # Print out the length of time it took to run everything
    echo "All done!  $(($diff / 60)) minutes and $(($diff % 60)) seconds have elapsed."
    echo '************************************************'

    # when debugging do not delete the log
    if [ -z "$show_debug" ]; then
      # Once the test is complete it's safe to delete the $filename.done file to allow another run
      RESET=`curl -is $service_url/unlink/$filename`
    fi
    break
  else
    # fetch the results
    GET_RESULT=`curl -s $verbose $service_url/get/$filename/$POSITION`

    if [ ! -z "$GET_RESULT" ]; then
      response=`echo $GET_RESULT | python -c 'import sys, json; print json.load(sys.stdin)["response"]'`

      # This would be better if $response was passed but for some reason that doesn't work.
      wrapOutput "$GET_RESULT"

      idx=`echo $GET_RESULT | python -c 'import sys, json; print json.load(sys.stdin)["resultsLength"]'`
      POSITION=$idx
      successMatch=`echo $GET_RESULT | grep -o "$gruntSuccessMessage"`
      failureMatch=`echo $GET_RESULT | grep -o "$gruntFailureMessage"`
      abortMatch=`echo $GET_RESULT | grep -o "$gruntAbortedMessage"`

      if [[ ! -z "$successMatch" ]]; then
        let doBreak=1
      fi
      if [[ ! -z "$failureMatch" || ! -z "$abortMatch" ]]; then
        echo ##teamcity[testFailed name='$service_url/automation/$env/$task' status='FAILURE' message='Test failed. See details for more info' details='$GET_RESULT']
        echo Grunt failed! $service_url/automation/$env/$task
        echo $GET_RESULT
        let doBreak=1
      fi
    fi
  fi
  sleep 10
done
