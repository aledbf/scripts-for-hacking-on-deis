Scripts to help with [Hacking on Deis](http://docs.deis.io/en/latest/contributing/hacking/) allowing to just run a script to install al the requirements another one to allow the test of a pull request or to build a local copy

**Installation**

As root execute `./host-setup.sh`

**Building deis**

As a normal user execute `./run.sh [PR number | local path to test]



*Changes to deis*

includes.mk
- define a new variable REGISTRY_PORT to allow a custom port

Makefile
- use REGISTRY_PORT

settings.py
- Use ip/port instead of socket to access postgres



**TODO:**

- [ ] find a way to not replace git-config
- [ ] check if the local docker configuration allows the use of insecure registries
- [ ] make squid container optional
- [ ] create a go binary using go-basher to run the scripts?