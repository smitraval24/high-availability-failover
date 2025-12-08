Accomplishment \- Vatsalkumar Patel (vpatel29)

* Implemented workflow to automatically rollback to previous working code in case of failure after deployment of new code ([Commit link](https://github.ncsu.edu/vpatel29/devops-project/commit/147f40de234b2bf0163ca4563a5fd53d8fa1689c))

Accomplishment \- Smit Sunilkumar Raval (sraval)

* Switch to standby server when primary crashes ([Commit Link](https://github.ncsu.edu/vpatel29/devops-project/tree/a54dfdaf8d6eefb22831fa6bbfc4b4edf6627ca5))   
* Error in the database replication periodically \- fixed that 


Next Steps \- Vatsal

* Making the database persistent every time the code is pushed  
* Integrate cloudflare for dns routing so that when server changes user can still visit the same url

Next Steps \- Smit

* Switch back to primary when it is back to normal (4-5 hours)  
* Setting up the cloudflare domain and redirecting the traffic from main server to standby server and from standby to main server according to the conditions

Retrospective

What Worked:

* Created backup of current healthy container in vcl2 before pulling new code  
* Solving the error of the database replication periodically 


What Didn’t work:

* We tried cloudflare integration but on free tier, everytime server starts there is a different url

 What are we going to do differently

* Will try to figure out other alternatives for cloudflare or use another vcl as the entry point. we have still not utilised ansible, so will need to use it for better management of vcl configuration.