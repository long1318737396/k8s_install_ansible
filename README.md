## Ansible install k8s

> 离线部署 | [在线部署](docs/online.md) | [离线包制作](docs/offlie-package.md) | [手动部署](https://github.com/long1318737396/k8s_install/tree/main)

## 部署需求

 ansible服务器需要能够操作各个目标主机，需要有root账户的密码，其他k8s节点以及harbor服务器需要能够访问通ansible服务器的38088端口，以此分发软件包

## 1.拷贝软件包到ansible服务器，或者复用harbor服务器

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

## 4.安装k8s
环境准备

```bash
#4.1 vi inventory/cluster/inventory.ini 配置连接K8s的主机名、IP地址、连接用户、密码

#4.2 vi inventory/cluster/group_vars/all/all.yml 配置K8s集群相关的环境变量
```
安装初始化参数

```bash
ansible-playbook -i inventory/cluster/inventory.ini playbooks/prepare.yml
```

## etcd安装

```bash
ansible-playbook -i inventory/cluster/inventory.ini playbooks/etcd-install.yml
```