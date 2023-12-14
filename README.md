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
export REGION=europe-central2
export ZONE=europe-central2-a
gcloud auth application-default set-quota-project $PROJECT
gcloud config set project $PROJECT
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE
```

## Create EMQX cluster in GKE

```bash
gcloud container clusters create emqx --machine-type e2-standard-8 --location $ZONE
gcloud container clusters get-credentials emqx
./generate-ansible-inventory.sh
ansible-playbook ansible/gke.yml
./install-emqx-operator.sh
kubectl create namespace emqx
kubectl apply -f emqx.yaml
kubectl -n emqx wait --for=condition=Ready emqx emqx --timeout=120s
kubectl -n emqx get svc
```

## Create loadgen VMs

You may need to adjust the subnet prefix based on region/zone, `10.186.x.x.` is for europe-central2-a

```bash
subnet_prefix="$(gcloud compute networks subnets list --regions $REGION --format json | jq '.[0].ipCidrRange' -r | cut -d'.' -f1,2)"
for i in $(seq 1 5); do
    gcloud compute instances create loadgen-$i \
        --zone $ZONE \
        --network-interface "subnet=default,aliases=$subnet_prefix.$i.0/28" \
        --image-project ubuntu-os-cloud \
        --image-family ubuntu-2204-lts \
        --machine-type e2-standard-4;
done
# init ssh connection credentials
gcloud compute ssh loadgen-1
./generate-ansible-inventory.sh "$subnet_prefix" 16
# point loadgens to NodePort
# ansible-playbook ansible/loadgen.yml --extra-vars emqtt_bench_targets="$(kubectl -n emqx get svc emqx-listeners -o json | jq '.spec.clusterIPs | join(",")' -r)"
# point loadgens to LB
ansible-playbook ansible/loadgen.yml --extra-vars emqtt_bench_targets="$(kubectl -n emqx get svc emqx-listeners -o json  | jq '.status.loadBalancer.ingress | map(.ip) | join(",")' -r)"
# point loadgens to node endpoints
# ansible-playbook ansible/loadgen.yml --extra-vars emqtt_bench_targets="$(kubectl -n emqx get endpoints/emqx-listeners -o json | jq '.subsets[].addresses | map(.ip) | join(",")' -r)"
ansible loadgen -m command -a 'systemctl start emqtt-bench' --become
```

## Cleanup

```bash
kubectl delete -f emqx.yaml
gcloud compute instances delete $(seq -s ' ' -f 'loadgen-%g' 1 5)
gcloud container clusters delete emqx
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
