/**
 * This module defines the paths and processes that enable executing grunt tasks on topperharley
 * for automated integration system tests.  The automation test pattern is to create tests and add a grunt task to run
 * them. The task can be executed either locally from the command line or on our deployed servers from the remote server
 * express app `xidontpanic`.  The purpose for this application is to help us schedule runs and manage
 * results (logs) that are returned to teamcity as test results.
 */
'use strict';
var express = require('express'),
    router = express.Router(),
    path = require("path"),
    fs = require("fs"),
    childProcessOptions = {},
    resultsLog,
    errorLog,
    makeUniqueLogName,
    runTest,
    logs = path.join(__dirname, '../logs/'),
    teamCityReporter = '--reporter=mocha-teamcity-reporter',

    /**
     * Every test run makes its on uniquely named log.
     */
    makeUniqueLogName = function(env, task) {
      var d = new Date(),
          logFileName;
      // let the name of the log be a combo of the env, task and a unix timestamp
      logFileName = d.getTime() + "_" + env + "_" + task +  ".log";

      // return the name of the unique file and set the error log
      errorLog = logFileName.replace('.log', '.err');
      return logFileName;
    };

    /**
     * This method starts the 'grunt %task%' task on topperharley
     */
    router.get('/automation/:env/:task', function(req, res) {
      var task = req.params.task,
        env = req.params.env;
      console.log({'RUNNING SYSTEM TESTS NOW ON ':req.params.env,
        'task is ' : req.params.task});
      //indicate that when the test begins polling for results should begin too
      runTest(req, res);
    });

  /**
   * Runs grunt tasks on topperharley
   *
   * @param req - specifies env in which to run and task to run
   * @param res - responds with the name of the resulting console log
   */
    runTest = function (req, res) {
      var env = req.params.env,
          task = req.params.task,
          // set current working directory to topperharley root
          cwd = path.join(__dirname, '../../topperharley'),
          task,
          child = require('child_process').spawn;
      // set the process environment variable which will be used by child_process
      process.env.NODE_ENV=env;
      process.env.verbose=true;

      //make log files unique
      resultsLog = makeUniqueLogName(env, task);

      // send back the name of the file
      res.send({ resultsLog: resultsLog });

      //spawn properties that describe how to behave and where to look
      childProcessOptions =
        {
          env: process.env,
          cwd: cwd,
          maxBuffer: 36044800,
          stdio: ['ignore',fs.openSync(logs + resultsLog, 'w+'),fs.openSync(logs + errorLog, 'w+')]
        };
      task = child('grunt',[task, teamCityReporter], childProcessOptions);

      task.on('exit', function (code) {
        console.log({'exiting code: ':code});
      });

      task.on('close', function (code) {
        console.log({'closing code: ':code});
      });

      task.on('error', function (err) {
        // print error to the xidontpanic express app's console
        console.log({'An error occurred while running system tests ':err.toString()});
      });
    };

    // grab the log file / results
    router.get('/get/:log?/:idx?', function(req, res) {
      fs.readFile(logs + req.params.log, 'utf8', function (err, data) {
        //substring lastIndexOf data is the begining
        var responseString;
        //only log what you have not yet read
        console.log({'params ' : req.params});
        responseString = data.substr(req.params.idx, data.length);
        res.send({response:responseString, resultsLength:data.length});
      });
    });

    // delete the log as a cleanup routine
    router.get('/unlink/:log?', function(req, res) {
      fs.unlink(logs + req.params.log, function (err) {
        if (err) throw err;
        res.status(200).end();
      });
    });

module.exports = router;
