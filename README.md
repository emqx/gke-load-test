# EMQX Load Test on GKE

## Pre-requisites

- [GCP project](https://cloud.google.com/resource-manager/docs/creating-managing-projects)
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-and-upgrading-ansible-with-pip)

## Run once

```bash
gcloud init
gcloud auth login
gcloud components update
export PROJECT=<your project id>
gcloud auth application-default set-quota-project $PROJECT
gcloud config set project $PROJECT
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud config set compute/region europe-central2
gcloud config set compute/zone europe-central2-a
```

## Create EMQX cluster in GKE

```bash
gcloud container clusters create emqx \
    --machine-type e2-standard-8 \
    --zone europe-central2-a \
    --node-locations europe-central2-a
gcloud container clusters get-credentials emqx
./generate-ansible-inventory.sh
ansible-playbook ansible/gke.yml
./install-emqx-operator.sh
kubectl create namespace emqx
kubectl apply -f emqx.yaml
kubectl -n emqx wait --for=condition=Ready emqx emqx --timeout=120s
kubectl -n emqx get svc emqx-dashboard
# internal LB for loadgens to connect to
kubectl apply -f ilb-svc.yaml
```

## Create loadgen VMs

```bash
for i in $(seq 1 5); do
    gcloud compute instances create loadgen-$i \
        --zone europe-central2-a \
        --network-interface "subnet=default,aliases=10.186.$((i+1)).0/28" \
        --image-project ubuntu-os-cloud \
        --image-family ubuntu-2204-lts \
        --machine-type e2-standard-4;
done
# init ssh connection credentials
gcloud compute ssh loadgen-1
# may need to adjust the subnet prefix based on region
# this one is for europe-central2-a
./generate-ansible-inventory.sh '10.186' 16
# ansible-playbook ansible/loadgen.yml --extra-vars emqtt_bench_targets="$(kubectl -n emqx get svc haproxy-ingress -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
# ansible-playbook ansible/loadgen.yml --extra-vars emqtt_bench_targets="$(kubectl -n emqx get svc ilb -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
ansible-playbook ansible/loadgen.yml --extra-vars emqtt_bench_targets="$(kubectl -n emqx get endpoints/emqx-listeners -o json | jq '.subsets[].addresses | map(.ip) | join(",")' -r)"
ansible loadgen -m command -a 'systemctl start emqtt-bench' --become
```

## Cleanup

```bash
gcloud compute instances delete $(seq -s ' ' -f 'loadgen-%g' 1 5)
kubectl delete -f ilb-svc.yaml
kubectl delete -f emqx.yaml
```

## Troubleshoting

```bash
# watch events
kubectl get events --all-namespaces --watch
# ssh on the GKE pool node, e.g.
gcloud compute ssh gke-emqx-default-pool-8ffb4312-bjcg
# list pods
crictl pods
# list containers
crictl ps
# get normal shell (then you can apt-get update, etc)
/usr/bin/toolbox
```
