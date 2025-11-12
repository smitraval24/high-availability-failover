Accomplishment \- Vatsalkumar Patel (vpatel29)

* Integrated postgres database into the coffee project (it is needed in our project to show database replication)  
* Wrote testing workflow to auto run tests on pr generation  
* Wrote workflow to autodeploy new code on successful pr merge  
* Workflow \- Upon successful health check of new code on primary server, backup updated code to standby server ([Commit link](https://github.ncsu.edu/vpatel29/devops-project/commit/472e990faa24f7bd49f41e3c53b023d86960b59f))

Accomplishment \- Smit Sunilkumar Raval (sraval)

*  Dockerize coffe project: Implemented this to keep the deployments consistent and same across different vcl machines.   
* Linting Workflow: Automated the linting check into the github actions to ensure that the style violations are checked and find bugs before we integrate it to production.  
* AutoMerge Bot/ Workflow integration: When we merge dev to main, and we resolve the conflicts and then merges that leaves both branches in different state so the main branch again PRs to dev to make both branches same.  
* Database replicate: We setup the communication between VCL 2 and VCL 3 database for every 2 minutes (only for testing purpose will increase this to 1 hr before final sub.) this will keep data available in both machines and will prevent total loss of data in the failure of one machine. Promotes high availibilty and recovery options. ([Commit link](https://github.ncsu.edu/vpatel29/devops-project/commit/8ecf31b0a5d5baefd13dd3e1bc781ebd1fe6f820))

Next Steps \- Vatsal

* Rollback to previous version in case updated version fails (4 hours)  
* Switch to standby server when primary crashes (8-10 hours)  
* Switch back to primary when it is back to normal (4-5 hours)

Next Steps \- Smit

*  While switching back from VCL 3 (cold standby) to VCL 2 (primary). We will ensure that the database is not completely wiped from vcl 2 and data from vcl 3 is dumped to vcl 2\. Instead we will make something that preserves the data on vcl 2 and while integrate the data from vcl 3  
* Integrating routing of the traffic from vcl 2 to vcl 3 when vcl 2 fails and then we start the application on vcl 3 and get the health status ok and database connection ok.   
* Also, traffic routing when vcl 2 is live and health check on that is ok.  
  

Retrospective

What Worked:

* Dockerization of the coffee project helped in the deployment of the project and running of the project across different vcl machines. Made it easy..  
* Integrating AutoMerge bot to have synced branches all the time.


What Didn’t work:

* Had to give self hosted runner on vcl 1 the permissions to be used by the github actions.  
* Communication between the 3 VCLs was a tricky part, we had to generate secret keys and allow access for successful automation and running of workflows.

 what are we going to do differently

* Till now we have not utilised ansible, so will need to use it for better management of automation.

