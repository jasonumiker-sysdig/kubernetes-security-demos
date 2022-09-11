# Demo Steps

## Pre-requisistes
1. Install the cluster (currently assumes M1 Mac) by running setup-cluster/setup-microk8s-vm-mac.sh

# Steps during live demo

## Kubernetes Namespace and RBAC Demo
1. `kubectl get pods -A` - We are currently signed in as the admin ClusterRole - we can do anything cluster-wide
1. `code team1.yaml` - Here we're creating a new namesapce, team1, and then creating the most basic and powerful Role possible that can do anything within that Namespace with *'s for apiGroups, Resources and Verbs. Like we said this is not a great idea especially on the verbs. Then finally we're binding that new Role to a user named Jane.
1. `kubectl api-resources` this shows all the different resources that we can control the use of in our RBAC
1. `kubectl get clusterrole admin -o yaml` - And we can ask for details on the few built-in ClusterRoles we can use as a guide. This admin role is intended to be for privileged users but not ones who can do anything. As you can see, the minute you don't do *s there is quite alot of YAML here.
1. `kubectl get clusterrole admin -o yaml | wc -l` - 324 lines of it!
1. But, we're much better than nothing doing a Role binding this user into a Namespace than a ClusterRole!
1. We have that team1 you saw as well as another similar Namespace and Role called Team2 - let's apply them
1. `kubectl apply -f team1.yaml && kubectl apply -f team2.yaml`
1. `kubectl config get-contexts` - Our two other users are already set up here in our kubectl - jane who has access to namespace team1 and john who has access to namespace team2
1. `kubectl config use-context microk8s-jane` - we've just logged in as Jane insted
1. `kubectl get pods -A` if we try to ask to see all the Pods in all the namespaces again we now get an error that we can't use the cluster scope
1. `kubectl get pods` removing the -A for all namespaces and it says we don't have any Pods in our team1 namespace which we do have access to
1. `cd example-voting-app` - Let's deploy an app to our namespace
1. `kubectl apply -f .`
1. `kubectl get pods` - As you can see we do have enough cluster access to deploy workloads within our team1 namespace
1. Now lets flip to John who is restricted to the team2 namespace
1. `kubectl config use-context-microk8s-john`
1. `kubectl get pods` We don't have any workloads deployed here yet
1. `kubectl get pods --namespace=team1` and we are not allowed to interact with the one Jane deployed to team1

So, that was a very quick overview of how to configure multi-tenancy of Kubernetes at the control plane level with Namespaces and Roles

## Host Isolation Demo

1. `kubectl config get-contexts` Confirming we are still signed in as John who should be limited to the team2 namespace (as we gave him a Role there rather than a ClusterRole)
1. `code nsenter.sh` - as we said you can ask for some things in your Podspecs such as hostPID and a privileged security context that allow you to break out of the Linux namespace boundaries. This asks for those things and then runs a tool called ns-enter to leave our Linux namespace. This should result in us having an interactive shell to the Kubernetes Node and as root.
1. `./nsenter.sh` - and there we go - root@microk8s-vm which is our Kubernetes Node
1. `ps aux` - when you are root in the host's Linux namespace you can see all the processes in all the containers
1. `crictl ps` - worse than that I can connect to the container runtime that Kubernetes manages and bypass Kubernetes to control it directly with crictl
1. `crictl ps | grep postgres` - There is a postgres database running as part of Jane's workload in team1. Lets interactively connect into it!
1. `crictl exec -it (copy/paste ID) /bin/bash` And now I am in that container interactively
1. `set | grep POSTGRES` and, since many secrets are decryted into the running containers as environment variables I can see those
1. `psql -U postgres -W` (then type password). And because there was a psql client in this container image I can now 
1. `\d` I can then do any queries the app can do... Ouch...
1. `\q`, `exit`, `exit`

So even though we properly set up our Kubernetes RBAC and Namespaces this host-level container isolation let us down as people who can launch a pod in one namespace with those defaults can 'own' the Node and everything running on it - even if those things are from a different Namespace.

The answer to this problem is the OPA Gatekeeper admission controller preventing me asking for those insecure parameters in my nsenter Podspec. This isn't there by default though in most clusters - even things like AWS EKS, Google GKE or MS AKS. Though in some you can opt-in to them. One way or the other if you are doing multi-tenancy you need to ensure you have it.

1. `cd opa-gatekeeper`
1. `code ./install-gatekeeper.sh` - this script will install the OPA Gatekeeper helm chart and then a few policies for it to enforce that will do just that
1. `./install-gatekeeper.sh` - let's run it
1. Oops we are still signed in as John so we don't have the rights to do that - back to our admin
1. `kubectl config use-context microk8s`
1. `./install-gatekeeper.sh` - there we go
1. `cd ..` - Okay now lets try our nsenter again
1. `./nsenter.sh` - As you can see we now have OPA Gatekeeper policies blocking all the insecure options nsenter was asking for - so that Pod is no longer allowed to launch. I am protected by this new admission controller!
1. `cd opa-gatekeeper`, `./uninstall-gatekeeper.sh` - removing this for a future demo though

Finally we had one more tool in our cluster all along here - Falco! That has been watching all this suspicious behavior.

1. Open Kibana tab (which you should have prepared before the demo)
1. (Filter by kubernetes.container_name = falco) - Here we have Kibana which we can use to search and filter through the logs every Pod on our cluster have been generating. We are interested in the ones from Falco
1. The fields we care about are output_fields.k8s.pod.name, priority and rule
1. There are heaps of Launch Ingress Remote File Copy Tools and Contact k8s API Server events. Lets filter those out to see what's left.
1. Now we can see our nsenter pod launch as a privileged container and we can also see that there as a Terminal shell in container on our db Pod

So while the Admission Controller should help such container escapes from happening it is good to couple it with Falco which watches what's happening and can alert us if it happens anyway somehow...

## NetworkPolicy Demo

We don't have too much time left for an exhaustive overview of NetworkPolices so this will be a very brief example of how they work.

1. `cd ..`
1. `cat launch-shell-in-pod.sh` this example unlike nsenter will stay properly contained in our team2 namespace
1. `curl vote.team1.svc.cluster.local` - hmm no curl - lets install it
1. `apt update && apt install curl -y`
1. `curl vote.team1.svc.cluster.local` - There we go. Let me up arrow and show you what we just did. There is an internal DNS-based service discovery in Kubernetes. So if I know a service exists and what namespace it is in, in this case the vote service in the team1 namespace, I can ask Kubernetes via DNS to send me there. And out of the box every Pod can talk to every pod in the cluster.
1. `cat networkpolicy.yaml` The answer here is to add a NetworkPolicy. This is a very simple example that just says that only things from the team1 namespace can talk to any of team1's Pods. You'd then add an explicit allow for any other communication in/out of the namespace that is required.
1. `kubectl apply -f networkpolicy.yaml` - we just applied that and it should get enforced immediatly. Let's try our curl again.
1. `curl vote.team1.svc.cluster.local` - and as you can see now that traffic from a Pod in team2 has been blocked