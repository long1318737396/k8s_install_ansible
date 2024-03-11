## Ansible install k8s

> 离线部署 | [在线部署](docs/online.md) | [离线包制作](docs/offlie-package.md) | [手动部署](https://github.com/long1318737396/k8s_install/tree/main)

## 部署需求

 01) ansible服务器需要能够操作各个目标主机，需要有root账户的密码，其他k8s节点以及harbor服务器需要能够访问通ansible服务器的38088端口，以此分发软件包

 02) k8s各个节点需要挂载单独的数据盘，比如挂载到/data，需要存储镜像，运行容器存储数据。

## 1.拷贝软件包到ansible服务器，或者复用harbor服务器，本文示例是安装在同一台

```bash
#1.1 拷贝软件包到ansible服务器，或者复用harbor服务器,然后解压压缩包
tar -zxvf k8s_install_ansible.tar.gz
cd k8s_install_ansible

#1.2 再次拷贝软件包到本地目录下，因为还需要通过代理分发到其他主机上
cp ../k8s_install_ansible.tar.gz .
```

## 2.启动ansible
由于离线环境部署ansible安装比较麻烦，所以封装在docker中了，可以在docker容器中操作ansible
```bash
#2.1 vi conf/config.sh 配置docker和containerd的存储目录
docker_data_root="/data/kubernetes/docker"
containerd_data_dir="/data/kubernetes/containerd"

#2.2 安装docker,确保docker ps、docker-compose命令可以使用
bash script/k8s/init.sh
bash script/k8s/1.contaienrd_over_docker_install.sh

#2.3 导入nginx和ansible镜像
docker load -i offlie/images/nginx.tar.gz 
docker load -i offlie/images/kubespray.tar.gz

#2.3 启动ansible
docker-compose up -d

#2.4 查看容器状态
docker-compose ps
```

## 3.安装harbor
确保docker和docker-compose以正确安装
```bash
#3.1 vi conf/config.sh 配置harbor的参数: IP地址、域名、登录密码和镜像存储位置
harbor_ip=192.168.150.14
harbor_hostname=myharbor.mtywcloud.com
https_certificate=/etc/harbor/cert/${harbor_hostname}.crt
https_private_key=/etc/harbor/cert/${harbor_hostname}.key
data_volume=/data/harbor/registry
harbor_admin_password=S6ag4KXGS

#3.2 安装harbor
bash script/harbor/create_cert.sh
bash script/harbor/install_harbor.sh

# 3.3 查看harbor状态,测试harbor是否可以正常登录
docker-compose ps
source conf/config.sh
echo "$harbor_ip $harbor_hostname" >> /etc/hosts
docker login $harbor_hostname --username admin --password $harbor_admin_password
```

## 4.nfs安装

nfs需要为后续的监控组件等提供持久化存储，离线安装需要找同系统的软件源,因系统的差异性，本脚本无法集成
需在nfs服务器上安装nfs服务，或复用其他机器

4.1 nfs安装
```bash
if [ -f /etc/debian_version ]; then
  apt update && apt install nfs-kernel-server -y
  systemctl enable nfs-kernel-server
  systemctl restart nfs-kernel-server

elif [ -f /etc/redhat-release ]; then
  yum install nfs-utils -y
  systemctl enable rpcbind --now
  systemctl enable nfs-server
  systemctl start nfs-server
else
  yum install nfs-utils -y
  systemctl enable rpcbind --now
  systemctl enable nfs-server
  systemctl start nfs-server
fi

```
4.2 nfs配置
```bash
#nfs的存储位置
nfs_path=/data/kubernetes/nfs  
mkdir -p ${nfs_path}
chmod -R 777 ${nfs_path}
echo "${nfs_path} *(rw,sync,no_root_squash,no_subtree_check)" | sudo tee -a /etc/exports
exportfs -ra
systemctl enable rpcbind --now
systemctl enable nfs-server
systemctl start nfs-server
showmount -e localhost
````

## 5.基础环境准备

5.1 集群节点安装nfs客户端,因k8s各个节点需要挂载nfs，需要安装nfs客户端

```bash
apt install nfs-common -y  #ubuntu机器
yum install nfs-utils -y   #centos机器 
```
5.2 配置环境变量
```bash
#vi inventory/cluster/inventory.ini 配置连接K8s的主机名、IP地址、连接用户、密码
```bash
[all]
master1 ansible_host=192.168.88.11 ansible_port=22 ansible_user="root" ansible_ssh_pass="admin@123"
master2 ansible_host=192.168.88.12 ansible_port=22 ansible_user="root" ansible_ssh_pass="admin@123"
master3 ansible_host=192.168.88.13 ansible_port=22 ansible_user="root" ansible_ssh_pass="admin@123"
node4 ansible_host=192.168.88.14 ansible_port=22 ansible_user="root" ansible_ssh_pass="admin@123"
[kube_control_plane]
master1
master2
master3
[etcd]
master1
master2
master3
[kube_node]
node4 
[k8s_cluster:children]
kube_control_plane
kube_node
```
#vi inventory/cluster/group_vars/all/all.yml 配置K8s集群相关的环境变量
```
安装所需的软件
如果是在线安装则需将vi inventory/cluster/group_vars/all/all.yml 配置中的yum_online_install 值设置为true
```bash
ansible-playbook -i inventory/cluster/inventory.ini playbooks/yum_online.yml
```
如果是离线安装则需要手动在k8s节点服务器上安装以下软件,本脚本集成了这些软件包，则需将vi inventory/cluster/group_vars/all/all.yml 配置中的yum_online_install 值设置为false
但只适用于centos8系列，因为是基于centos8提取的rpm包，其他系统请自行安装，并不保证100%会安装成功,例如nfs相关包，
如果安装失败则需要手动安装
```bash
Centos

vim
wget
conntrack
socat
ipvsadm 
ipset
telnet
nfs-utils
unzip
bash-completion
```

5.3 初始化内核参数、关闭防火墙、swap、分发二进制文件到k8s集群的各个节点上
```bash
ansible-playbook -i inventory/cluster/inventory.ini playbooks/prepare.yml
```


## 6.etcd安装
配置etcd相关参数,如果挂载数据盘到/data可以保持默认
vi inventory/cluster/group_vars/all/all.yml
```bash
#etcd配置
##etcd的存储目录
etcd_data_dir: '/data/kubernetes/etcd'
##存放etcd的证书和配置文件的目录
etcd_dir: '{{ cluster_dir }}/etcd'
##etcd的备份目录
etcd_backup_dir: /data/backup/k8s/etcd
```
```bash
ansible-playbook -i inventory/cluster/inventory.ini playbooks/etcd-install.yml
```
## containerd安装

