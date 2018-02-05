FROM ubuntu:artful

ARG KUBECTL_VERSION=v1.9.2
ENV KUBECONFIG /secret/kubeconfig

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8

VOLUME /secret

# Python packages

ADD requirements.txt requirements.txt

RUN apt-get update -q \
 && apt-get upgrade -q -y \
 && apt-get install -q -y \
    vim \
    python-pip \
    bash-completion \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && pip install -r requirements.txt

# Kubectl
ADD https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl

RUN echo 'source <(kubectl completion bash)\n \
[[ $PS1 && -f /usr/share/bash-completion/bash_completion ]]\n \
   . /usr/share/bash-completion/bash_completion\n' >> ~/.bashrc


ADD playbook /playbook

WORKDIR /playbook
CMD bash
