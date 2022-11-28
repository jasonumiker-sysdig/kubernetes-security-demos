# Kubernetes security demos

These are demos of the topics discussed my recent blog post - https://sysdig.com/blog/multi-tenant-isolation-boundaries-kubernetes/

## Pre-requisites

Mac:
1. Install microk8s with a `brew install microk8s`
1. Clone this repo - `git clone https://github.com/jasonumiker-sysdig/kubernetes-security-demos.git`
1. Run `setup-cluster/setup-microk8s-vm.sh` if on an Intel MAC and `setup-cluster/setup-microk8s-vm-arm.sh` if on an M1/M2 Mac.

NOTE: On an M1/M2 Mac the Falcosidekick UI is currently unsupported so the workshop substitutes in an Elastic/Kibana to see the Falco events instead.

Windows:
1. Be running a Pro or Enterprise version of Windows 10/11 that can do Hyper-V
1. Install microk8s - https://microk8s.io/docs/install-windows
1. Install git - https://gitforwindows.org/
1. Clone this repo - `git clone https://github.com/jasonumiker-sysdig/kubernetes-security-demos.git`
1. Run `setup-cluster/setup-microk8s-vm-win.sh` from within a git bash shell/session

Linux (via a VM managed by multipass):
1. Install snap if it isn't included in your distro (e.g. `sudo dnf install snapd` on Fedora)
1. Run `snap install multipass`
1. Clone this repo - `git clone https://github.com/jasonumiker-sysdig/kubernetes-security-demos.git`
1. Run `setup-cluster/setup-microk8s-vm.sh`

AWS:
1. Install node.js, npm, python3, pip3 and the AWS CLI 
    1. Mac - `brew install node@16 python@3.9 awscli`
1. cd `setup-cluster/aws-cdk`
1. Edit cdk.json and enter the AWS account number, region and the number of attendees that you'd like
1. Run `npm install`
1. Run `pip3 install -r requirements.txt`
1. Run `npx cdk bootstrap` (once per account)
1. Run `npx cdk deploy --all`
1. Set the passwords on all the attendee IAM Users so they can sign into the console - then provide the AWS Account #, IAM username and password to the attendees

## Signing in as an attendee if the environment is in a local VM
1. Run `multipass shell microk8s-vm`

Here are some other useful commands to manage that VM once it exists:
* `multipass stop microk8s-vm` - shut the VM down
* `multipass start microk8s-vm` - start it up
* `multipass delete microk8s-vm && multipass purge` - delete and then purge the VM

## Signing in as an attendee if the environment is in AWS
1. Go to https://console.aws.amazon.com/
1. Choose IAM User and enter the AWS Account Number as well as the Attendee IAM Username and Password the facilitator will provide
1. Go to the EC2 Console
1. Tick the box next to the instance named the same as your username and then click the Connect button
1. Pick the Session Manager tab then click the Connect button
1. `sudo bash` then `cd ~` as all the tooling was installed for the root user

## Kubernetes Namespace and RBAC Demo
1. `kubectl get pods -A` - We are currently signed in as the admin ClusterRole - we can do anything cluster-wide
1. `cd ~/kubernetes-security-demos`
1. `cat team1.yaml` - Here we're creating a new namespace, team1, and then creating the most basic and powerful Role possible that can do anything within that Namespace with *'s for apiGroups, Resources and Verbs. Like we said this is not a great idea especially on the verbs. Then finally we're binding that new Role to a user named Jane.
1. `kubectl api-resources` this shows all the different resources that we can control the use of in our RBAC
1. `kubectl get clusterrole admin -o yaml | less` - And we can ask for details on the few built-in ClusterRoles we can use as a guide. This admin role is intended to be for privileged users but not ones who can do anything. As you can see, the minute you don't do *s there is quite a lot of YAML here.
1. `kubectl get clusterrole admin -o yaml | wc -l` - 315 lines of it!
1. But, we're much better than nothing doing a Role binding this user into a Namespace than a ClusterRole!
1. We have that team1 you saw as well as another similar Namespace and Role called Team2 - let's apply them
1. `kubectl apply -f team1.yaml && kubectl apply -f team2.yaml`
1. `kubectl config get-contexts` - Our two other users are already set up here in our kubectl - jane who has access to namespace team1 and john who has access to namespace team2
1. `kubectl config use-context microk8s-jane` - we've just logged in as Jane instead
1. `kubectl get pods -A` if we try to ask to see all the Pods in all the namespaces again we now get an error that we can't use the cluster scope
1. `kubectl get pods` removing the -A for all namespaces and it says we don't have any Pods in our team1 namespace which we do have access to
1. `cd ~/kubernetes-security-demos/demos/network-policy/hello-app`
1. `kubectl apply -f .` - Let's deploy an app to our namespace
1. `kubectl get pods` - As you can see we do have enough cluster access to deploy workloads within our team1 namespace
1. `kubectl describe deployments hello-client-allowed` - Note under Pod Template -> Environment that a Kubernetes secret (hello-secret) is getting mounted as the environment variable API_KEY at runtime
1. Now lets flip to John who is restricted to the team2 namespace
1. `kubectl config use-context microk8s-john`
1. `kubectl get pods` - we don't have any workloads deployed here yet
1. `kubectl get pods --namespace=team1` - and we are not allowed to interact with the one Jane deployed to team1

So, that was a very quick overview of how to configure multi-tenancy of Kubernetes at the control plane level via Namespaces and Roles. And, how much YAML it takes to move away from *'s for the resources and verbs in your Role definitions.

## Host Isolation Demo

### Container Escape - impacting the Node and/or other workloads running there
1. `kubectl config get-contexts` - Confirming we are still signed in as John who should be limited to the team2 namespace (as we gave him a Role there rather than a ClusterRole)
1. `kubectl describe secret hello-secret -n team1` - as expected we can't get at team1's secrets as john (as he only has access to team2's namespace)
1. `cd ~/kubernetes-security-demos/demos`
1. `cat nsenter-node.sh` - as we said you can ask for some things in your Podspecs such as hostPID and a privileged security context that allow you to break out of the Linux namespace boundaries of containers. This asks for those things and then runs a tool called ns-enter to leave our Linux namespace for the host one. This should result in us having an interactive shell to the Kubernetes Node and as root.
1. `./nsenter-node.sh` - and there we go - we're now root@microk8s-vm which is our Kubernetes Node
1. `ps aux` - when you are root in the host's Linux namespace you can see all the processes in all the containers
1. `crictl ps` - and, worse than that, I can connect to the container runtime that Kubernetes manages directly (bypassing Kubernetes entirely) with the crictl command
1. `crictl ps | grep hello-client-allowed` - There is the API_KEY secret as part of Jane's workload in team1. Lets interactively connect into it and see if we can get it!
1. `export HELLO_CLIENT_CONTAINER_ID=$(crictl ps | grep hello-client-allowed | awk 'NR==1{print $1}')` to put the container ID of hello-client-allowed in an environment variable for us
1. `crictl exec -it $HELLO_CLIENT_CONTAINER_ID /bin/sh` And now I am in that container interactively
1. `set | grep API_KEY` and, since secrets are decrypted into the running containers as environment variables or files, I can see those this way - even from things from other Kubernetes Namespaces
1. `exit` to leave the container
1. `crictl stop $HELLO_CLIENT_CONTAINER_ID && crictl rm $HELLO_CLIENT_CONTAINER_ID` and I can bypass Kubernetes' API and as the container runtime to stop/delete containers/Pods Kubernetes has launched on this Node as well
1. `exit` to leave the container

So even though we properly set up our Kubernetes RBAC and Namespaces this host-level container isolation let us down as people who can launch a pod in one namespace with those defaults can 'own' the Node and everything running on it - even if those things are from a different Namespace.

### Exploiting vulnerabilities (known CVEs, unknown zero-days or vulnerabilities within your own code etc.) at runtime

There are also a number of things that we can do without needing to escape the container. The worst vulnerabilities allow you to do remote code execution (RCE) of the services via malformed network calls to them or insufficient security of the APIs they are exposing.

To illustrate the worst-case-scenario of that we have the simplest and least secure Python app possible that we are calling security-playground:
1. `cd ~/kubernetes-security-demos/demos/security-playground`
1. `cat app.py` - we can see just see just how simple this Python app is - it'll read any file you ask it to with a RESTful GET, write any file you ask it to with a RESTful POST and even execute any file you want it to with a POST to the /exec URI path.
1. `cat example-curls.sh` Since this is just REST we can do these exploits with just `curl` commands.
1. `kubectl config use-context microk8s` - Let's go back to our admin role (to allow our kubectl get nodes to work)
1. `kubectl apply -f security-playground.yaml` to deploy security-playground
1. `kubectl get pods -n security-playground` - keep running this until our Pod has come up
1. `./example-curls.sh` - to run these example curls which will:
    1. Read a sensitive file (/etc/shadow)
    1. Write a file to a sensitive location (/bin)
    1. Read that new file back from that sensitive location
    1. Install dig from apt and then do some DNS queries against the Kubernetes service discovery
    1. Download as script that, in turn, tries to run some cyrpto mining within our Pod (note that this currently doesn't work on arm like M1/M2 Mac - working on getting the crypto mining example working there too)

This example is interesting because:
1. It could represent a worst-case zero-day - the next Log4j or Struts etc. - that we don't yet know about and that our container image vulnerability scans won't pick up yet without a public CVE in the databases
1. It could be our own code which will never have a public CVE against it

We'll see in a future section that Falco recorded this nefarious runtime behavior for us.

### Open Policy Agent (OPA) Gatekeeper
The answer to this problem is the OPA Gatekeeper admission controller preventing me asking for those insecure parameters in my nsenter Podspec. This isn't there by default though in most clusters - even things like AWS EKS, Google GKE or MS AKS. Though in some you can opt-in to them. One way or the other if you are doing multi-tenancy you need to ensure you have it.

1. `cd ~/kubernetes-security-demos/opa-gatekeeper`
1. `cat ./install-gatekeeper.sh` - this script will install the OPA Gatekeeper Helm chart and then a few policies for it to enforce (which are in the form of Kubernetes custom resource definition (CRD) files/objects) that will do just that
1. `./install-gatekeeper.sh` - let's run it
1. `cd ~/kubernetes-security-demos/demos` - Okay now lets try our nsenter again
1. `./nsenter-node.sh` - As you can see we now have OPA Gatekeeper policies blocking all the insecure options nsenter was asking for that allowed us to peform our escape - so that Pod is no longer allowed to launch. I am protected by this new admission controller!
1. `cd ~/kubernetes-security-demos/opa-gatekeeper/policies/constraint-templates/` then `cat` the various files in here to look at the policies (called constraint-templates) that made that possible
1. `cd ~/kubernetes-security-demos/opa-gatekeeper/policies/constraints` then `cat` the various files in here - while the previous constraint-templates are the polices constraints say when - and when not to - apply those policies. So constraint-templates are not enforced until a constraint says where and/or where not to apply it.
1. `cd ~/kubernetes-security-demos/opa-gatekeeper`
1. `./uninstall-gatekeeper.sh` - removing Gatekeeper for a future demo to work though

These actually came from the Gatekeeper library on Github where there are a number of additional examples here - https://github.com/open-policy-agent/gatekeeper-library/tree/master/library

Also there is a good tool to test out your Rego (OPA's declarative language for policies) here - https://play.openpolicyagent.org/

### Falco
Finally, we've had a free opensource tool in our cluster all along here watching what we've been up to - [Falco](https://falco.org/). Falco watches streams of data such as the Linux kernel syscalls on all your Nodes, as well as your Kubernetes audit trail, for suspicious behavior and can alert you to it in realtime. This is often referred to as "Runtime threat detection."

There are actually two Falcos running - one watching the Linux kernel syscalls on each Node as a DaemonSet and one watching the Kubernetes audit trail as a Deployment. All of their events are aggregated by Falco Sidekick which can fan them out to any number of destinations such as your SIEM, your alerting systems like Pagerduty or your messaging tools like Slack.

1. Open Falcosidekick UI by going to port http://(IP):30282 on your Node
    1. If you are signed into a microk8s-vm on your Mac or Windows machine, you can run `kubectl get nodes -o wide` to find the IP address to use (the INTERNAL-IP)
    1. If run in AWS then this will be the public IP of the EC2 instance
1. Note the Rules that have been firing. Many of these things might not be issues but it is good that Falco has recorded them so we can decide if they are or they aren't in our case.
1. Go to the Events Tab to see the Events in more detail.
    1. First we'll search for `nsenter` in the search box under the Sources dropdown:
      1. We can see that john is a "disallowed" K8s user calling the API. This Falco default has an allow-list of expected users. We'll need to tune that for our environment or turn it off - I'll show you how to do that in a second.
      1. Then we can see the `Launch Privileged Container` (those privileges enabled us to escape the container later)
      1. Then we can see that john did an `Attach/Exec into the Pod` (connected interactively) - Also note that, while the `Launch Privileged Container` was determined from the Node's Linux syscalls, that this was determined from the k8s_audit trail - and we see a combined/aggregated timeline of it all here.
    1. Now search for `terminal` in the search box:
      1. Here is the `Terminal shell in container` we did to connect to the hello-client via crictl when we escaped onto the host
    1. Finally search for `playground` in the search box:
      1. We see a `Read sensitive file untrusted` from the curl that read /etc/shadow
      1. We see a `Launch Package Management Process in Container` where our curl download the `dig` from apt
      1. Then we see the `Launch Suspicious Network Tool in Container` when we ran that `dig` against Kubernetes' DNS service discovery
      1. Then we see a `Launch Ingress Remote File Copy Tool in Container` in response to a `curl` to download a script
      1. And finally the `Detect crypto miners using the Stratum protocol` when that script attemped to launch crypto mining within our container exploiting our mock "zero day".

Alternatively, as the Falcosidekick UI doesn't yet work on the M1 Mac, you can use Elastic and Kibana to view the events. This is deployed by default instead of the non-working Falcosidekick UI when you use setup-microk8s-vm-arm.sh today. And, if you want both Falcosidekick UI as well as Elastic/Kibana, then you can deploy setup-microk8s-vm-with-elastic.sh.
<details>
  <summary>(Optional) Elastic & Kibana Instructions</summary>
  
1. Open Kibana by going to port http://(IP):30283 on your Node
    1. If you are signed into a microk8s-vm on your Mac or Windows machine, you can run `kubectl get nodes -o wide` to find the IP address to use (the INTERNAL-IP)
    1. If run in AWS then this will be the public IP of the EC2 instance
1. Tick the Don't show again box and click the Dismiss button on the Your data is not secure box in the lower right
1. Click the link to Explore on my own on the Welcome to Elastic screen
1. Click the hamburger menu in the upper right and choose Discover under Analytics
1. Click the button to Create index pattern
1. In name type `logstash*`, pick @timestamp in the Timestamp field dropdown and then click the Create index pattern button
1. Go back to the hamburger menu in the upper right and choose Discover under Analytics again
1. In the search box type `kubernetes.namespace_name : "falco"` to show the logs from our two Falco agents (one for the Node syscalls and one for the Kubernetes audit trail)
1. Make sure that the time range to the right of the search box we are looking at covers everything we've done today
1. Click the carrot/arrow next to the top document and if you hover over Actions to the left of the each Field you'll see four options - Filter for, Filter out, Toggle column in table and Filter for field present. We want to show a few columns so click on Toggle column for these two Fields:
  1. `output_fields.k8s_pod_name`
  1. `rule`
1. Those fields without a Pod name are from the Kubernetes audit trail and those with one is from the Node's syscalls. You can see more details for each one by expanding its carrot
1. We can explore what we know happened with the following queries (replace what was in the search box with these and run them - ensuring that the timeframe still covers our activity to the right of it):
  1. `kubernetes.namespace_name : "falco" and "nsenter"`
    1. We can see that john is a "disallowed" K8s user calling the API. This Falco default has an allow-list of expected users. We'll need to tune that for our environment or turn it off - I'll show you how to do that in a second.
    1. Then we can see the `Launch Privileged Container` (those privileges enabled us to escape the container later)
    1. Then we can see that john did an `Attach/Exec into the Pod` (connected interactively) - Also note that, while the `Launch Privileged Container` was determined from the Node's Linux syscalls, that this was determined from the k8s_audit trail - and we see a combined/aggregated timeline of it all here.
    1. Finally we see the `The docker client is executed in a container` that shows our `crictl` commands we were running
  1. `kubernetes.namespace_name : "falco" and "terminal"`
    1. Here is the `Terminal shell in container` we did to connect to the hello-client via crictl when we escaped onto the host
  1. `kubernetes.namespace_name : "falco" and "playground"`
    1. We see a `Read sensitive file untrusted` from the curl that read /etc/shadow
    1. We see a `Launch Package Management Process in Container` where our curl download the `dig` from apt
    1. Then we see the `Launch Suspicious Network Tool in Container` when we ran that `dig` against Kubernetes' DNS service discovery
    1. Then we see a `Launch Ingress Remote File Copy Tool in Container` in response to a `curl` to download a script
    1. And finally the `Detect crypto miners using the Stratum protocol` when that script attemped to launch crypto mining within our container exploiting our mock "zero day".

</details>

#### Falco Tuning

Nearly all of the Falco rules will have an "escape hatch" list or macro where you can allow-list those things (namespaces, or user or container names etc.) that should be excluded from the rule firing. This is especially true for those Rules that say "disallowed" such as `Disallowed K8s User` and `Create Disallowed Namespace`

Tuning out any noise so that most, if not all, of the Events that fire here are meaningful is important.

Here is the default ruleset that was installed by the Helm chart in our cluster with regards to the Kubernetes Audit Trail - https://github.com/falcosecurity/charts/blob/master/falco/rules/k8s_audit_rules.yaml

The `Disallowed K8s User` rule is as follows - it builds on lists and we are including the relevant one for our "escape hatch" allowed_k8s_users here as well:
```
- list: allowed_k8s_users
  items: [
    "minikube", "minikube-user", "kubelet", "kops", "admin", "kube", "kube-proxy", "kube-apiserver-healthcheck",
    "kubernetes-admin",
    vertical_pod_autoscaler_users,
    cluster-autoscaler,
    "system:addon-manager",
    "cloud-controller-manager",
    "system:kube-controller-manager"
    ]

- rule: Disallowed K8s User
  desc: Detect any k8s operation by users outside of an allowed set of users.
  condition: kevt and non_system_user and not ka.user.name in (allowed_k8s_users) and not ka.user.name in (eks_allowed_k8s_users)
  output: K8s Operation performed by user not in allowed list of users (user=%ka.user.name target=%ka.target.name/%ka.target.resource verb=%ka.verb uri=%ka.uri resp=%ka.response.code)
  priority: WARNING
  source: k8s_audit
  tags: [k8s]

```

So, the way to not have it fired `Disallowed K8s User` for john or jane is to add them to `allowed_k8s_users`. And, rather than edit the upstream default policy document, the way we do this is to override it in our own policy file that gets applied after/on top of that one. These are stored in Kubernnetes as Configmaps:
1. `kubectl edit configmap falco-rules -n falco`
1. Add the following under the macro under customrules.yaml as follows (note that you'll need to know how to use the vi editor - if you don't then feel free to skip this step):
```
apiVersion: v1
data:
  customrules.yaml: |-
    - macro: user_known_ingress_remote_file_copy_activities
      condition: container.name startswith "hello-client" or k8s.ns.name = "monitoring"
    - list: allowed_k8s_users
      items: [
        "minikube", "minikube-user", "kubelet", "kops", "admin", "kube", "kube-proxy", "kube-apiserver-healthcheck",
        "kubernetes-admin",
        vertical_pod_autoscaler_users,
        cluster-autoscaler,
        "system:addon-manager",
        "cloud-controller-manager",
        "system:kube-controller-manager",
        "john",
        "jane"
        ]
```

The way that it has been deployed by the Helm chart Falco will automatically be reloaded when this ConfigMap changes to apply our new rules.

Falco's default rules are a good start but, as you can see, require some tuning for your environment. Some rules where it says 'disallowed' in the rule require you to add certain users/namespaces/etc to lists. You can also add exclusions to cater for certain services and add-ons that require additional privileges or that don't (yet?) honor best practices to remove noise.

There is a great Falco 101 training on more details available here - https://learn.sysdig.com/falco-101

### Running containers as non-root

It is also worth nothing that, in addition to the additional privileges we gave nsenter in the Kubernetes parameters, running as the root user within the container was required for this escape to work. Using Falco to alert on that when it happens (which as you can see it does by default with the rules in the Helm chart), as well as perhaps having OPA Gatekeeper block that so it isn't even possible, you can iterate through your environment to get all of your containers that don't truly need to be root running as non-root to really elevate your security posture.

This change to non-root often requires rebuilding your container with a new Dockerfile. A good example of the difference in Dockerfiles required to do it is [nginx](https://hub.docker.com/_/nginx) vs. [nginx-unprivileged](https://hub.docker.com/r/nginxinc/nginx-unprivileged). By default nginx wants to use port 80 and so runs as root in order to be able to do so. But they also build a version of it that doesn't and uses 8080 instead:
* nginx Dockerfile that runs as root - https://github.com/nginxinc/docker-nginx/blob/fef51235521d1cdf8b05d8cb1378a526d2abf421/mainline/debian/Dockerfile
* nginx Dockerfile that creates a nginx user/group (UID and GID 101) and uses that instead - https://github.com/nginxinc/docker-nginx-unprivileged/blob/main/Dockerfile-debian.template

### Scanning containers for vulnerabilities in your pipelines

While there are many tools available for this, Docker has a partnership with Snyk and built this functionality right into the Docker CLI you most likely are using to build your containers today. As part of this there is a free tier which requires you to be logged in to Docker Hub to use it.

NOTE: If you do not have a free Docker Hub login, and don't want to sign up for one now, then this section is optional. Just review the steps rather than going through them and then move on to the next section.

1. Run `cd ~/kubernetes-security-demos/demos/security-playground`
1. Run `docker build -t security-playground:latest .`
1. Create a free Docker Hub (https://hub.docker.com/) login if you do not already have one. Being signed into Docker CLI is also useful for increasing your limits to pull from Docker Hub (as they throttle authenticated free users less than anonymous ones on pulls).
1. Run `docker login` to log in to the Docker CLI
1. Run `docker scan security-playground:latest > scan-results.txt`. The first time that you do this it will ask if you consent to using Snyk - answer y.
1. Run `cat scan-results.txt` and we see we have many vulnerabilities in this image. Look for a block like this at the bottom:
    ```
    Base Image              Vulnerabilities  Severity
    python:3.7.15-bullseye  311              4 critical, 37 high, 26 medium, 244 low

    Recommendations for base image upgrade:

    Alternative image types
    Base Image                 Vulnerabilities  Severity
    python:3.7-slim-bullseye   48               0 critical, 0 high, 0 medium, 48 low
    python:3.9-slim            48               0 critical, 0 high, 0 medium, 48 low
    python:3.12-rc-slim        48               0 critical, 0 high, 0 medium, 48 low
    python:3.7.15-slim-buster  70               0 critical, 2 high, 0 medium, 68 low
    ```
1. It gives us suggested changes to our base image to fix this - of these if we want to stay with the same version of Python (3.7) is `python:3.7-slim-bullseye`. Slim images have fewer things in them so, assuming we don't need something that isn't in slim (we'll need to test this still works to be sure), it makes sense it'll have fewer vulnerabilities too.
1. Run `nano Dockerfile` and change `FROM python:3.7-bullseye` to `FROM python:3.7-slim-bullseye`
1. Then rerun `docker build -t security-playground:latest .`
1. And then `docker scan security-playground:latest > scan-results2.txt` and note that we have the fewer vulnerabilities we expected.

## NetworkPolicy Demo

Now let's look at how NetworkPolicies work and how to isolate network traffic within our cluster(s).

We had already deployed a workload in team1 that included a server Pod (hello-server) as well as two client Pods (hello-client-allowed and hello-client-blocked). 

Out of the box all traffic is allowed which you can see as follows:
1. `kubectl logs deployment/hello-client-allowed -n team1` as you can see it is getting a response from the server
1. `kubectl logs deployment/hello-client-blocked -n team1` and our 'blocked' Pod is not yet blocked and is getting a response from the server as well
1. `cd ~/kubernetes-security-demos/demos/network-policy/hello-app`
1. `kubectl apply -f  hello-client.yaml -n team2` Lets also deploy another set of our client Pods to the team2 namespace
1. `kubectl logs deployment/hello-client-allowed -n team2` As you can see both the allowed
1. `kubectl logs deployment/hello-client-blocked -n team2` And the 'blocked' Pods can contact our server pods from other Namespaces by default as well.

There are two common ways to write NetworkPolicies to allow/deny traffic - against labels and against namespaces. And you can actually combine the two now as well. Let's start with namespaces:
1. `cd ~/kubernetes-security-demos/demos/network-policy`
1. `cat network-policy-namespace.yaml` As you can see here we are saying we are allowing traffic from Pods within the namespace team1 to Pods with the label app set to hello-server (implicitly also in the Namespace team1 where we are deploying the NetworkPolicy).
1. `kubectl apply -f network-policy-namespace.yaml -n team1` Lets apply that NetworkPolicy
1. `kubectl logs deployment/hello-client-allowed -n team1` and `kubectl logs deployment/hello-client-blocked -n team1` both of our Pods in team1 can reach the server
1. `cd ~/kubernetes-security-demos/demos/network-policy/hello-app`
1. `kubectl logs deployment/hello-client-allowed -n team2` and `kubectl logs deployment/hello-client-blocked -n team2` but neither of our Pods in team2 can anymore

Now let's try it with labels - which is better for restricting traffic within a Namespace to least privilege:
1. `cd ~/kubernetes-security-demos/demos/network-policy`
1. `cat network-policy-label.yaml` As you can see here we are saying we are allowing traffic from Pods with the label app set to hello to Pods with the label app set to hello-server. 
1. `kubectl apply -f network-policy-label.yaml -n team1` Lets apply this NetworkPolicy (overwriting the last one as they have the same name)
1. `kubectl logs deployment/hello-client-blocked -n team1` And now we'll see that our blocked Pod where the app label is not set to hello is now being blocked by the NetworkPolicy
1. `kubectl logs deployment/hello-client-blocked -n team2` and `kubectl logs deployment/hello-client-allowed -n team2` There was another side effect of this policy too in that it also blocked all traffic from other Namespaces

In order to allow pods with the hello app label from all Namespaces (not just the one the NetworkPolicy is deployed into) you need to add another namespaceSelector with a wildcard allowing that:
1. `cat network-policy-label-all-namespaces.yaml` As you can see here we added one more line to the from with that {} wildcard for Namespaces. We added this as an AND rather than an OR by including it in the same from section.
1. `kubectl apply -f network-policy-label-all-namespaces.yaml -n team1`
1. `kubectl logs deployment/hello-client-allowed -n team2` Now the allowed pods in other namespaces like team2 will work as well

That was a very basic introduction to NetworkPolicies. There are a number of other good/common examples on this site to explore the topic further - https://github.com/ahmetb/kubernetes-network-policy-recipes
