Automated Integration Applications for Player Management API 
====================================================

Overview
---------------
Our system-level integration tests are performed and controlled by the TeamCity build pipe.  Each test is different and run on distinct schedules depending on the requirements.  

Here's a list of tests and how they are triggered:  

 * [system-tests](https://bithub.brightcove.com/videocloud/topperharley#system-test) - These tests were designed for Topperharley and are run periodically either on demand (qa and staging) or at scheduled intervals (production). The system-test builds are defined here on [TeamCity](http://trunkcity.vidmark.local/project.html?projectId=ExperimentalPlayerManagement_SystemTest&tab=projectOverview).  
  * For the system-test automation builds on TeamCity there is a failure condition that says _Fail build if number of tests is less than 8_ If the number of tests changes this value will have to be adjusted.
 
 
 * [quick-version-update](https://bithub.brightcove.com/videocloud/topperharley) — Occasionally we are required to rollout new Single Video Template versions to our customer base. The process by which this is done is controlled by scripts that are executed with particular parameter settings, depending on the actions required.  This automation application tests and ensures that the script and its components are in proper working order. _Note this is incomplete_
 
For all the tests above, they can be triggered locally via grunt tasks. The xidontpanic express application is where we defined and exposed endpoints which can be requested thus triggering the grunt tasks. The xidontpanic applications job is to monitor the progress of the tests, relay stdout/stderr and indicate when the tests has completed.  The results are interpreted by TeamCity and recorded. Failures are reported to HipChat where team members are alerted and further action then takes place.

