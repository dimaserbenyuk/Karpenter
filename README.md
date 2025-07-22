helm pull oci://public.ecr.aws/karpenter/karpenter --version 1.5.1 --untar

Pulled: public.ecr.aws/karpenter/karpenter:1.5.1
Digest: sha256:1fdb55b1b413967824f42442a4a9f269ca2cb933ccc855f48eeddfcaaf782cd4


helm upgrade --install --namespace karpenter --create-namespace karpenter ./karpenter --values karpenter/values.yaml

aws ec2 describe-instances \
  --instance-ids i-097c986bb24cb30e5 \
  --region eu-central-1 \
  --query "Reservations[*].Instances[*].{State:State.Name,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,Tags:Tags}" \
  --output table  

https://codeberg.org/hjacobs/kube-ops-view

aws eks update-kubeconfig \                                                         
  --name eks-cluster \
  --region eu-central-1 \
  --profile default \
  --kubeconfig ~/.kube/eks-cluster

export KUBECONFIG=~/.kube/eks-cluster