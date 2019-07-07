# ************************ Configurable Params ************************
inventory='nbt'
user='vagrant'
master_ip='172.71.199.100'
# *********************************************************************

rm -f /home/krittin/.ssh/known_hosts
mkdir -p ~/.kube

KUBECONFIG_PATH=~/.kube/${inventory}.conf

scp ${user}@${master_ip}:/home/${user}/.kube/config $KUBECONFIG_PATH

echo "export KUBECONFIG=\$KUBECONFIG:$KUBECONFIG_PATH" >> ~/.bashrc
source ~/.bashrc

chmod 600 $KUBECONFIG_PATH 

sed -i -e "s/kubernetes-admin/${inventory}-admin/g" $KUBECONFIG_PATH

kubectl config use-context ${inventory}-admin@${inventory}

kubectl version
kubectl get nodes -o wide
kubectl proxy &
kubectl apply -f configs/clusteradmin-rbac.yml
kubectl -n kube-system describe secret kubernetes-dashboard-token | grep 'token:' | grep -o '[^ ]\+$'
