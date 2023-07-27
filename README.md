# Kubernetes security demos

This project is intended to provide two things:
1. Automation to quickly and easily spin up a Kubernetes lab to learn about its security on nearly any machine (Windows, Mac (both Intel and M1/M2), or Linux). It can run in as little as 2 CPUs and 4GB of RAM so it should run on even modest laptops. 
    1. And, if you make a mistake, you can just delete this VM and re-run this automation to be back to a working environment in minutes (so can learn and tinker without any fear)!
1. Various demonstration scenarios documented in this README to help you learn about many of the common Kubernetes security features and challenges, and how to address them, first-hand in that lab environment.

I'm a hands-on learner and built this for myself awhile back - and now I want to share it with the community.

## Pre-requisites
This lab provisions an Ubuntu virtual machine (VM) with [multipass](https://multipass.run/) and then installs [microk8s](https://microk8s.io/) within it.

Mac (via a VM managed by multipass):
1. (If you don't already have it) Install [Homebrew](https://brew.sh/)
    1. You can do this by running the command `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
1. Install microk8s with a `brew install microk8s`
1. Clone this repo - `git clone https://github.com/jasonumiker-sysdig/kubernetes-security-demos.git`
1. Run `setup-cluster/setup-microk8s-vm.sh`

Windows (via a VM managed by multipass):
1. Be running a Pro or Enterprise version of Windows 10/11 that can do Hyper-V
1. Install microk8s - https://microk8s.io/docs/install-windows
1. Install git - https://gitforwindows.org/
1. Clone this repo - `git clone https://github.com/jasonumiker-sysdig/kubernetes-security-demos.git`
1. Run `setup-cluster/setup-microk8s-vm.sh` from within a git bash shell/session

Linux (via a VM managed by multipass):
1. Install snap if it isn't included in your distro (e.g. `sudo dnf install snapd` on Fedora)
1. Run `snap install multipass`
1. Clone this repo - `git clone https://github.com/jasonumiker-sysdig/kubernetes-security-demos.git`
1. Run `setup-cluster/setup-microk8s-vm.sh`

## Signing in to the environment
* Run `multipass shell microk8s-vm`

OR

* Run `cd ~/.kube` and `multipass transfer microk8s-vm:/home/ubuntu/.kube/config config` to copy the Kubeconfig to your host. If you have installed `kubectl`, and also have `git cloned` this git repo to the host in your home directory, then you can run the commands from there rather than a shell within the VM if you'd prefer.

Here are some other useful commands to manage that VM once it exists:
* `multipass stop microk8s-vm` - shut the VM down
* `multipass start microk8s-vm` - start it up
* `multipass delete microk8s-vm && multipass purge` - delete and then purge the VM

## Demo of Kubernetes Role-based Access Control (RBAC) and Namespaces
Regardless of how you have people authenticate/login to Kubernetes (AWS IAM Users/Roles for EKS, Google Account to GKE, OIDC to your identity provider, etc.) Kubernetes does its own authorization. It does this via its [Role Based Access Control (RBAC)](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) APIs.

At a high level, the way Kubernetes RBAC works is that you either assign your Users a [ClusterRole](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole), which gives them cluster-wide privileges, or you assign them a [Role](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole) which restricts them to only have access to a particular Namespace within the cluster. A [Namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) is a logical boundary and grouping within Kubernetes to isolate the resources of particular teams from one another - so if you put different teams in different Namespaces via Roles the idea is that they can safely share the cluster as they shouldn't be able to interfere with one another. This is known as multi-tenancy. As you'll see, there is a little more to it than that, though...

For both a Role as well as a ClusterRole you also assign what rules/permissions to it for what it can do. These are additive - in that there are no denys only allows.

Let's explore how this all works:
1. `kubectl get pods -A` - We are currently signed in as the cluster-admin ClusterRole - we can do anything cluster-wide
1. `kubectl api-resources` this shows all the different resources that we can control the use of in our RBAC. 
    1. It also shows which of them are Namespaced (can be managed by Roles) vs. which can't (and are therefore cluster-wide and need a ClusterRole to manage them)
    1. And it also shows the short names for each resource type (which you can use to save typing in kubectl)
1. `kubectl get clusterrole admin -o yaml | less` (press space to page down and q to exit) - This built-in admin role can explicitly do everything - and so you can clone it and remove those things you don't want a user to be able to do. As you can see, the minute you don't do *'s there is quite a lot of YAML here to go through!
1. `kubectl get clusterrole admin -o yaml | wc -l` - 324 lines of it!
1. You can see the details about this and the other built-in Roles such as edit and view [here](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles)
1. `cd ~/kubernetes-security-demos`
1. `cat team1.yaml` - Here we're creating a new namespace, team1, and then creating the most basic and powerful Role possible that can do anything within that Namespace with *'s for apiGroups, Resources and Verbs. Then we're binding that new Role to a user named Jane.
    1. This is perhaps overly permissive as it:
        1. Includes the verbs like [Escalate](https://kubernetes.io/docs/concepts/security/rbac-good-practices/#escalate-verb) and [Impersonate](https://kubernetes.io/docs/concepts/security/rbac-good-practices/#escalate-verb) that most users won't need.
        1. Allows the Role to create other Roles and bind Users to it within that Namespace
        1. Allows the Role to create/edit all the NetworkPolicy firewalls for that Namespace and its workloads
        1. Etc.
    1. But, just by using a Role and Namespace rather than a ClusterRole (which would be cluster-wide), we're still doing pretty well here.
1. We have that team1 you saw as well as another similar Namespace and Role called Team2 that is bound to another user (John) - let's apply them!
1. `kubectl apply -f team1.yaml && kubectl apply -f team2.yaml`
1. `kubectl config get-contexts` - Our two other users are already set up here in our kubectl - `jane` who we just gave access to namespace `team1` and `john` who we just gave access to namespace `team2`
1. `kubectl config use-context microk8s-jane` - we've just logged in as Jane instead
1. `kubectl get pods -A` if we try to ask to see all the Pods in all the namespaces again we now get an error that we can't use the cluster scope
1. `kubectl get pods` removing the -A for all namespaces and it says we don't have any Pods in our team1 namespace - which we do have access to see
1. `cd ~/kubernetes-security-demos/demos/network-policy/hello-app`
1. `kubectl apply -f .` - Let's deploy an app to our namespace - which we do have access to do
1. `kubectl get pods` - As you can see we do have enough cluster access to deploy workloads within our team1 namespace
1. `kubectl describe deployments hello-client-allowed` - Note under Pod Template -> Environment that a Kubernetes secret (hello-secret) is getting mounted as the environment variable API_KEY at runtime
1. `kubectl exec -it deploy/hello-client-allowed -n team1 -- /bin/sh` and then `whoami` (or whatever else you want to run) and then `exit` - Jane even has permission to connect interactively into all the Pods in their team1 namespace and run whatever commands she wants at runtime.
1. `kubectl apply -f ../../../team1-noexec.yaml` - If we set our Role to the those 324 explicit lines above but with the `pod/exec` commented out then that will block us from being able to do this.
    1. Note that we are still signed in as Jane - since we had put *'s we actually have the rights to change our own Role permissions in this way!
1. `kubectl exec -it deploy/hello-client-allowed -n team1 -- /bin/sh` - trying it again you'll see that it is blocked
1. `kubectl config use-context microk8s-john` - Now lets flip to John who is restricted to the team2 namespace
1. `kubectl get pods` - we don't have any workloads deployed here yet
1. `kubectl get pods --namespace=team1` - and, as expected we are not allowed to interact with the one Jane deployed to team1

So, that was a very quick overview of how to configure multi-tenancy of Kubernetes at the control plane level via Namespaces and Roles. And, how much YAML it takes to move away from *'s for the resources and verbs in your Role definitions.

## Demo of how to detect and prevent common runtime container exploits/escapes

We are going to perform a variety of common container/Kubernetes exploits and then show how to block/defend against them as well as detect them if they happen in real-time with Falco.

### Our General-Purpose Zero-Day Remote Code Execution (RCE) Vulnerability - security-playground

[Sysdig](https://sysdig.com/) (the company that donated Falco to the CNCF - and that I work for) provides a general-purpose example exploit called Security Playground https://github.com/sysdiglabs/security-playground that is a Python app which just reads, writes and/or executes whatever paths you GET/POST against it. To understand a bit more about how that works, have a look at [app.py](demos/security-playground/docker-build-security-playground/app.py).

The idea with this is is to imagine there is another critical remote code execution (RCE) vulnerability (CVE) that there is not yet a known - so your vulnerability scans don't pick it up. What can you do to detect that this is being exploited - and prevent/mitigate any damage it'd cause.

You can see various examples of how this works in the [example-curls.sh](demos/security-playground/example-curls.sh) file.

**NOTE:** This is deployed with a service of type NodePort - if you'd prefer it to be a load balancer then modify that manifest to reconfigure the Service as well as the bash script addresses how you'd prefer. Just be careful as this is a very insecure app (by design) - don't put it on the Internet!

### Deploying and exploiting security-playground

Run the following commands:
1. `kubectl config get-contexts` - confirm we are still signed in as John (to Namespace team2)
1. `cd ~/kubernetes-security-demos/demos/security-playground/`
1. `kubectl apply -f security-playground.yaml` - deploy security-playground
1. `kubectl get all` - We deployed a Deployment (that created a ReplicaSet that created a Pod) as well as a NodePort service exposing security-playground on port 30000 on our Node.
1. `curl ./example-curls.sh` to see all of the various commands we're going to run to exploit security-playground's remote code execution vulnerability
1. `kubectl config use-context microk8s` to change our context to the cluster admin so the script can get our Node IP (which requires a ClusterRole)
1. `./example-curls.sh` to run all of our example exploits

Watch the output scroll by to see this from the attacker's perspective.

### How and why did that all work?

In addition to our RCE vulnerability in the code, the [security-playground.yaml](demos/security-playground/security-playground.yaml) example has three key security issues:
1. It runs as root
1. It is running with `hostPID: true`
1. It is running in a privileged securityContext

When these (mis)configurations are done together, they allow you to escape out of the container isolation boundaries and be root on the host. This allows you not just full control over the host but also over/within the other containers.

We used two tools to break out and escalate our privileges:
* [nsenter](https://manpages.ubuntu.com/manpages/jammy/man1/nsenter.1.html) which allows you to switch Linux namespaces (if you are allowed)
    1. Not to be confused with Kubernetes Namespaces, [Linux Namespaces](https://en.wikipedia.org/wiki/Linux_namespaces) are a feature of the Linux kernel used by containers to isolate them from each other.
* [crictl](https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md) which is used to control the local container runtime containerd bypassing Kubernetes (if you can connect to the container socket)

### Trying it again against security-playground-restricted

The [security-playground-restricted.yaml](demos/security-playground/security-playground-restricted.yaml) example fixes all these vulnerabilities in the following ways:
1. We build a container image that runs as a non-root user (this required changes to the Dockerfile as you'll see in [Dockerfile-unprivileged](demos/security-playground/docker-build-security-playground/Dockerfile-unprivileged) vs. [Dockerfile](demos/security-playground/docker-build-security-playground/Dockerfile)).
1. The PodSpec not only doesn't have hostPID and a privileged securityContext but it adds in the new Pod Security Admission (PSA) restricted mode for the namespace which ensures that they can't be added to the PodSpec to restore them.
1. The restricted PSA also keeps us from trying to specify/restore root permissions (the original container could only run as Root but this one we could specify in the PodSpec to run it as root and it would still work).

Run the following:
1. `cd ~/kubernetes-security-demos/demos/security-playground`
1. `cat security-playground-restricted.yaml`
1. `kubectl apply -f security-playground-restricted.yaml`
1. `./example-curls-restricted.sh`

Comparing the results - this blocked almost everything that worked before:
||security-playground|security-playground-restricted|
|-|-|-|
|1|allowed|blocked (by not running as root)|
|2|allowed|blocked (by not running as root)|
|3|allowed|blocked (by not running as root)|
|4|allowed|blocked (by not running as root and no hostPID and no privileged securityContext)|
|5|allowed|blocked (by not running as root and no hostPID and no privileged securityContext)|
|6|allowed|blocked (by not running as root and no hostPID and no privileged securityContext)|
|7|allowed|blocked (by not running as root and no hostPID and no privileged securityContext)|
|8|allowed|allowed|

So, even with still having this critical remote code execution vulnerability in our service, we still managed to block nearly everything through better configuration/posture for this workload!

And, on that last item, we are going to show how to block that via NetworkPolicies to limit the Internet egress to download the miner and/or allow it to connect to the miner pool as required in a later section.

### Pod Security Admission - preventative enforcement

There is now a feature built-in to Kubernetes (which GA'ed in 1.25) to enforce standards around these insure options in a PodSpec which undermine your workload/cluster security - [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/).
        
This works by [adding labels onto each Namespace](https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/). There are two standards that it can warn about and/or enforce for you - baseline and restricted.
1. [baseline](https://kubernetes.io/docs/concepts/security/pod-security-standards/#baseline) - this prevents the worst of the parameters in the PodSpec such as hostPid and Privileged but still allows the container to run as root
1. [restricted](https://kubernetes.io/docs/concepts/security/pod-security-standards/#baseline) - this goes further and blocks all insecure options including running as non-root

We enabled that for the Namespace security-playground-restricted - let's see how that works:

Run:
1. `kubectl describe namespace security-playground-restricted` and note that we are both warning and enforcing the restricted standard here.
1. `kubectl apply -f security-playground.yaml -n security-playground-restricted` and see how our original insecure security-playground isn't allowed here by the PSA.

Getting all of your workload namespaces to baseline if not restricted makes a big difference in the security posture of your cluster.

### Kubebench
In addition to PSAs, there are some free opensource tools like [kubebench](https://github.com/aquasecurity/kube-bench) that can scan your cluster's posture against things like the CIS Benchmark. The CIS benchmark covers not just those options but many other aspects of cluster security.

To see this in action:
1. `cd ~/kubernetes-security-demos/demos`
1. `kubectl apply -f kubebench-job.yaml` to deploy a one-time job to scan your cluster. You could change this job's Kubernetes spec to run regularly if you wanted.
1. `kubectl logs job/kube-bench` to have a look at the results:
    1. The 5.2.2, 5.2.3, 5.2.7 failures if they had been fixed on security-playground would have prevented the attack. Many other things here would be a good idea to fix too in order to have the ideal security posture.

### Falco - detecting threats in real-time
Finally, we've had a free opensource tool in our cluster all along here watching what we've been up to - [Falco](https://falco.org/). Falco watches streams of data such as the Linux kernel syscalls on all your Nodes, as well as your Kubernetes audit trail, for suspicious behavior and can alert you to it in realtime. This is often referred to as "Runtime Threat Detection."

All of their events are aggregated by Falco Sidekick which can fan them out to any number of destinations such as your SIEM, your alerting systems like Pagerduty or your messaging tools like Slack.

It ships with a variety of sensible rules by default. You can find out more about those in this GitHub Repo - https://github.com/falcosecurity/rules

1. Open Falcosidekick UI by going to port http://(Node IP):30282 on your Node and using the username/password of admin/admin
    1. You can run `kubectl get nodes -o wide` to find the IP address to use (the INTERNAL-IP)
1. Note the Rules that have been firing. Many of these things might not be issues but it is good that Falco has recorded them so we can decide if they are or they aren't in our case.
1. Go to the Events Tab to see the Events in more detail.
    1. First we'll search for `playground` in the search box under the Sources dropdown then scroll to the bottom and increase the Rows per page to 50. Note the following events:
        1. `Launch Privileged Container` and `Create Privileged Pod` - this is where security-playground was launched with privileges that we were able to exploit to escape the container
        1. `Read sensitive file untrusted` - this is where we tried to read /etc/shadow
        1. `Write below binary dir` - this happened whenever we wrote to /bin and /usr/bin (/bin/hello in the container and /usr/bin/crictl on the Node)
        1. `Launch Package Management Process in Container` - this is where we `apt install`'ed nmap 
        1. `Drop and execute new binary in container` - this happened whenever we added a new executable at runtime (that wasn't in the image) and ran it (nmap, xmrig, the dpkg to discover our architecture)
        1. `Launch Suspicious Network Tool in Container` - this is where we ran nmap to perform a network discovery scan
        1. `The docker client is executed in a container` - this fires not just on the Docker CLI but also other similar tools like crictl and kubectl
            1. You can see all of the commands we ran as we were breaking out of container including our psql SELECT in the cmdline of these events
        1. `Launch Ingress Remote File Copy Tools in Container` - this is where we ran wget to get crictl and xmrig
    1. (Optional) remove the search and/or go to the Dashboard tab to look around through the various other Events that Falco has caught during our session

### (Optional) Scanning containers for vulnerabilities in your pipelines

While there are many tools available for this, Docker has a scan built-in to their CLI. Let's try using that one.

NOTE: This won't run within your microk8s VM and instead needs to run on a machine with Docker (Linux) or Docker Desktop (Windows or Mac) installed.

1. Clone the repository if you haven't already on the machine running Docker `git clone https://github.com/jasonumiker-sysdig/kubernetes-security-demos.git`
1. Run `cd ~/kubernetes-security-demos/demos/security-playground/docker-build-security-playground` (assuming you cloned it to your home directory)
1. Run `docker build -t security-playground:latest .`
1. If you are running Docker Desktop then you should already have scout, otherwise run `curl -sSfL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh | sh -s --`
1. Run `docker login` to log into Docker if you are not already
1. Run `docker scout cves security-playground:latest` as you can see there are many low severity vulnerabilities
1. Run `docker scout cves security-playground:latest --only-severity "critical, high"` to filter out anything that isn't a critical or a high - and now (as of today) I don't see any.

In this case we haven't even pushed this image to the registry yet and are able to see if it has vulnerabilities/CVEs we need to fix before pushing and deploying it.

## Demo of Kubernetes Native Firewall (NetworkPolicy)

Now let's look at how NetworkPolicies work and how to isolate network traffic within our cluster(s) - as well as egress traffic to the Internet

We had already deployed a workload in team1 that included a server Pod (hello-server) as well as two client Pods (hello-client-allowed and hello-client-blocked). 

Out of the box all traffic is allowed which you can see as follows:
1. `kubectl logs deployment/hello-client-allowed -n team1` as you can see it is getting a response from the server
1. `kubectl logs deployment/hello-client-blocked -n team1` and our Pod to be blocked is not yet blocked and is getting a response from the server as well
1. `cd ~/kubernetes-security-demos/demos/network-policy`
1. `cat example-curl-networkpolicy.sh` to see an example curl to try to hit hello-server (in Namespace team1) from security-playground (in Namespace team2)
1. `./example-curl-networkpolicy.sh` to run that and see the response

There are two common ways to write NetworkPolicies to allow/deny traffic dynamically between workloads within the cluster - against labels and against namespaces.
1. `cat network-policy-namespace.yaml` As you can see here we are saying we are allowing traffic from Pods within the namespace team1 to Pods with the label app set to hello-server (implicitly also in the Namespace team1 where we are deploying the NetworkPolicy).
1. `kubectl apply -f network-policy-namespace.yaml` Lets apply that NetworkPolicy
1. `kubectl logs deployment/hello-client-allowed -n team1` and `kubectl logs deployment/hello-client-blocked -n team1` both of our Pods in team1 can still reach the server
1. `./example-curl-networkpolicy.sh` but our security-playground in team2 can't any longer (it will time out)

Now let's try it with labels - which is better for restricting traffic within a Namespace to least privilege:
1. `cat network-policy-label.yaml` As you can see here we are saying we are allowing traffic from Pods with the label app set to hello to Pods with the label app set to hello-server. 
1. `kubectl apply -f network-policy-label.yaml` Lets apply this NetworkPolicy (overwriting the last one as they have the same name)
1. `kubectl logs deployment/hello-client-blocked -n team1` And now we'll see that our blocked Pod where the app label is not set to hello is now being blocked by the NetworkPolicy
1. `./example-curl-networkpolicy.sh` and this also blocked our NetworkPolicy both because it isn't in the same Namespace and it doesn't have the correct label as well.

NetworkPolicies don't just help us control Ingress traffic, though, they can also help us control egress traffic - including preventing access to the Internet.

1. `cat network-policy-deny-egress.yaml` this policy will deny all egress access to all pods in the Namespace it is deployed in.
    1. Any required egress traffic will need an explicit allow - either added to this policy or in another one applied in the same Namespace
1. `kubectl apply -f network-policy-deny-egress.yaml -n security-playground-restricted` to apply this to the security-playground-restricted Namespace
1. `kubectl delete --all pods --namespace=security-playground-restricted` - we had already downloaded xmrig to our running container - start a fresh one to properly test the NetworkPolicy
1. `../security-playground/example-curls-restricted.sh` to re-run our example-curls against security-playground-restricted. We've now blocked the entire attack - even while still having this critical remote code execution vulnerability in it!

That was a very basic introduction to NetworkPolicies. There are a number of other good/common examples on this site to explore the topic further - https://github.com/ahmetb/kubernetes-network-policy-recipes

There is also a great editor for NetworkPolicies at https://editor.networkpolicy.io/
