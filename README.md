# Kubernetes open-source security demos

## Pre-requisistes

Mac (assumes M1/M2/ARM at the moment):
1. Install microk8s with a `brew install microk8s kubectl helm`
1. Run setup-cluster/setup-microk8s-vm-mac.sh

Windows:
1. Be running a Pro or Enterprise version of Windows 10/11 that can do Hyper-V
1. Install microk8s - https://microk8s.io/docs/install-windows
1. Install git - https://gitforwindows.org/
1. Install the kubectl (https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/) and helm (https://helm.sh/docs/intro/install/) CLIs
1. Run setup-cluster/setup-microk8s-vm-win.sh from within a git bash shell/session

Ubuntu:
1. Clone this repo - `git clone https://github.com/jasonumiker-sysdig/kubernetes-opensouce-security-demos.git`
1. Change into the setup directory - `cd kubernetes-opensource-security-demos/setup-cluster`
1. Run the setup script - `sudo ./setup-microk8s.sh`

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

## Signing in as an attendee if the environment is in AWS
1. Go to https://console.aws.amazon.com/
1. Choose IAM User and enter the AWS Account Number as well as the Attendee IAM Username and Password the facilitator will provide
1. Go to the EC2 Console
1. Tick the box next to the instance named the same as your username and then click the Connect button
1. Pick the Session Manager tab then click the Connect button
1. `sudo bash` then `cd ~` as all the tooling was installed for the root user

## Kubernetes Namespace and RBAC Demo
1. `kubectl get pods -A` - We are currently signed in as the admin ClusterRole - we can do anything cluster-wide
1. `cat team1.yaml` - Here we're creating a new namesapce, team1, and then creating the most basic and powerful Role possible that can do anything within that Namespace with *'s for apiGroups, Resources and Verbs. Like we said this is not a great idea especially on the verbs. Then finally we're binding that new Role to a user named Jane.
1. `kubectl api-resources` this shows all the different resources that we can control the use of in our RBAC
1. `kubectl get clusterrole admin -o yaml | less` - And we can ask for details on the few built-in ClusterRoles we can use as a guide. This admin role is intended to be for privileged users but not ones who can do anything. As you can see, the minute you don't do *s there is quite alot of YAML here.
1. `kubectl get clusterrole admin -o yaml | wc -l` - 324 lines of it!
1. But, we're much better than nothing doing a Role binding this user into a Namespace than a ClusterRole!
1. We have that team1 you saw as well as another similar Namespace and Role called Team2 - let's apply them
1. `kubectl apply -f team1.yaml && kubectl apply -f team2.yaml`
1. `kubectl config get-contexts` - Our two other users are already set up here in our kubectl - jane who has access to namespace team1 and john who has access to namespace team2
1. `kubectl config use-context microk8s-jane` - we've just logged in as Jane insted
1. `kubectl get pods -A` if we try to ask to see all the Pods in all the namespaces again we now get an error that we can't use the cluster scope
1. `kubectl get pods` removing the -A for all namespaces and it says we don't have any Pods in our team1 namespace which we do have access to
1. `cd demos/network-policy/hello-app` - Let's deploy an app to our namespace
1. `kubectl apply -f .`
1. `kubectl get pods` - As you can see we do have enough cluster access to deploy workloads within our team1 namespace
1. Now lets flip to John who is restricted to the team2 namespace
1. `kubectl config use-context-microk8s-john`
1. `kubectl get pods` We don't have any workloads deployed here yet
1. `kubectl get pods --namespace=team1` and we are not allowed to interact with the one Jane deployed to team1

So, that was a very quick overview of how to configure multi-tenancy of Kubernetes at the control plane level with Namespaces and Roles

## Host Isolation Demo

1. `kubectl config get-contexts` Confirming we are still signed in as John who should be limited to the team2 namespace (as we gave him a Role there rather than a ClusterRole)
1. `cat nsenter.sh` - as we said you can ask for some things in your Podspecs such as hostPID and a privileged security context that allow you to break out of the Linux namespace boundaries. This asks for those things and then runs a tool called ns-enter to leave our Linux namespace. This should result in us having an interactive shell to the Kubernetes Node and as root.
1. `./nsenter.sh` - and there we go - root@microk8s-vm which is our Kubernetes Node
1. `ps aux` - when you are root in the host's Linux namespace you can see all the processes in all the containers
1. `crictl ps` - worse than that I can connect to the container runtime that Kubernetes manages and bypass Kubernetes to control it directly with crictl
1. `crictl ps | grep hello-client-allowed` - There is a password environment variable as part of Jane's workload in team1. Lets interactively connect into it!
1. `crictl exec -it (copy/paste ID) /bin/sh` And now I am in that container interactively
1. `set | grep API_KEY` and, since secrets are decrypted into the running containers as environment variables or files I can see those - even from things from other Kubernetes Namespaces
1. `exit` to leave the container
1. `crictl stop (copy/paste ID) && crictl rm (copy/paste ID)` and I can bypass Kubernetes' API and stop/delete containers Kubernetes has launched on this Node directly against the container runtime as well

So even though we properly set up our Kubernetes RBAC and Namespaces this host-level container isolation let us down as people who can launch a pod in one namespace with those defaults can 'own' the Node and everything running on it - even if those things are from a different Namespace.

### Open Policy Agent (OPA) Gatekeeper
The answer to this problem is the OPA Gatekeeper admission controller preventing me asking for those insecure parameters in my nsenter Podspec. This isn't there by default though in most clusters - even things like AWS EKS, Google GKE or MS AKS. Though in some you can opt-in to them. One way or the other if you are doing multi-tenancy you need to ensure you have it.

1. `cd opa-gatekeeper`
1. `cat ./install-gatekeeper.sh` - this script will install the OPA Gatekeeper helm chart and then a few policies for it to enforce that will do just that
1. `./install-gatekeeper.sh` - let's run it
1. Oops we are still signed in as John so we don't have the rights to do that - back to our admin
1. `kubectl config use-context microk8s`
1. `./install-gatekeeper.sh` - there we go
1. `cd ..` - Okay now lets try our nsenter again
1. `./nsenter.sh` - As you can see we now have OPA Gatekeeper policies blocking all the insecure options nsenter was asking for - so that Pod is no longer allowed to launch. I am protected by this new admission controller!
1. `cd opa-gatekeeper/contraint-templates` then `cat` the various files in here to look at the policies (called contraint-templates) that made that possible
1. `cd ../constraints` then `cat the various files in here - the constraints which say where to apply and where not to apply the contraint-tempaltes/policies
1. `cd ..`, `./uninstall-gatekeeper.sh` - removing Gatekeeper for a future demo to work though

These actually came from the Gatekeeper library on Github where there are a number of additional examples here - https://github.com/open-policy-agent/gatekeeper-library/tree/master/library

Also there is a good tool to test out your Rego (OPA's declarative language for policies) here - https://play.openpolicyagent.org/

### Falco
Finally we had one more tool in our cluster all along here - Falco! That has been watching all this suspicious behavior.

There are actually two Falcos running - one watching the Linux kernel syscalls on each Node as a Daemonset and one watching the Kubernetes audit trail as a Deployment. All of their events are aggregated by Falco Sidekick which can fan them out to any number of destinations such as your SIEM, your alerting systems like Pagerduty or your messaging tools like Slack.

1. Open Falcosidekick UI by going to port 30282 on your Node
    1. If using microk8s on a Mac or Windows machine this is the first IP listed when you run `multipass list` for microk8s-vm (the one that starts with 172.)
    1. If run in AWS then this will be the public IP of the EC2 instance
1. Go to the Events Tab
1. Type `nsenter` in the search box and note the rules triggered on both the Kubernetes audit trail as well as the Node syscalls including `Create Privileged Pod`, `Launch Privileged Container` and `Attach/Exec Pod`
1. Then type `terminal` in the search box and see the Terminal shell in container events. These were triggered when we ran crictl exec on the host after we escaped there from the Pod.

So, if somebody is able to exploit a misconfiguration or a vulnerability to escape the host boundaries then Falco can be configured to not only keep an audit trail of that but to alert you in real-time.

Falco's default rules are a good start but, as you can see, require some tuning for your environment. Some rules where it says 'disallowed' in the rule require you to add certain users/namespaces/etc to lists. You can also add exclusions to cater for certain services and add-ons that require additional privileges or that don't (yet?) honor best practices to remove noise.

There is a great Falco 101 training on more details available here - https://learn.sysdig.com/falco-101

## NetworkPolicy Demo

Now let's look at how NetworkPolicies work and how to isolate network traffic within our cluster(s).

We had already deployed a workload in team1 that included a server Pod (hello-server) as well as two client Pods (hello-client-allowed and hellow-client-blocked). 

Out of the box all traffic is allowed which you can see as follows:
1. `kubectl logs deployment/hello-client-allowed -n team1` as you can see it is getting a response from the server
1. `kubectl logs deployment/hello-client-blocked -n team1` and our 'blocked' Pod is not yet blocked and is getting a response from the server as well
1. `cd hello-app`
1. `kubectl apply -f  hello-client.yaml -n team2` Lets also deploy another set of our client Pods to the team2 namespace
1. `kubectl logs deployment/hello-client-allowed -n team2` As you can see both the allowed
1. `kubectl logs deployment/hello-client-bocked -n team2` And the 'blocked' Pods can contact our server pods from other Namespaces by default as well.

There are two common ways to write NetworkPolicies to allow/deny traffic - against labels and against namespaces. And you can actually combine the two now as well. Let's start with namespaces:
1. `cd ..`
1. `cat network-policy-namespace.yaml` As you can see here we are saying we are allowing traffic from Pods within the namespace team1 to Pods with the label app set to hello-server (implicity also in the Namespace team1 where we are deploying the NetworkPolicy).
1. `kubectl apply -f network-policy-namespace.yaml -n team1` Lets apply that NetworkPolicy
1. `kubectl logs deployment/hello-client-allowed -n team1` and `kubectl logs deployment/hello-client-blocked -n team1` both of our Pods in team1 can reach the server
1. `cd hello-app`
1. `kubectl logs deployment/hello-client-allowed -n team2` and `kubectl logs deployment/hello-client-bocked -n team2` but neither of our Pods in team2 can anymore

Now let's try it with labels - which is better for restricting traffic within a Namespace to least privilege:
1. `cat network-policy-label.yaml` As you can see here we are saying we are allowing traffic from Pods with the label app set to hello to Pods with the label app set to hello-server. 
1. `kubectl apply -f network-policy-label.yaml -n team1` Lets apply this NetworkPolicy (overwriting the last one as they have the same name)
1. `kubectl logs deployment/hello-client-blocked -n team1` And now we'll see that our blocked Pod where the app label is not set to hello is now being blocked by the NetworkPolicy
1. `kubectl logs deployment/hello-client-blocked -n team2` and `kubectl logs deployment/hello-client-allowed -n team2` There was another side effect of this policy too in that it also blocked all traffic from other Namespaces

In order to allow pods with the hello app label from all Namespaces (not just the one the NetworkPolicy is deployed into) you need to add another namespaceSelector with a wildcard allowing that:
1. `cat network-policy-label-all-namespaces.yaml` As you can see here we added one more line to the from with that {} wildcard for Namespaces. We added this as an AND rather than an OR by including it in the same from section.
1. `kubectl apply -f network-policy-label-all-namespaces.yaml -n team1`
1. `kubectl logs deployment/hello-client-allowed -n team2` Now the allowed pods in other namespaces like team2 will work as well

That was a very basic introduction to NetworkPolicies. There are a number of other good/common examples on this site to explore the topic further - https://github.com/ahmetb/kubernetes-network-policy-recipes
