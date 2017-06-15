FROM python:2.7

ADD https://storage.googleapis.com/kubernetes-release/release/v1.6.4/bin/linux/amd64/kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl
ENV KUBECONFIG /secret/kubeconfig

ADD playbook /playbook

VOLUME /secret

ADD requirements.txt requirements.txt
RUN pip install -r requirements.txt

RUN apt-get update && apt-get install -y vim bash-completion && apt-get clean
RUN echo 'source <(kubectl completion bash)\n \
[[ $PS1 && -f /usr/share/bash-completion/bash_completion ]]\n \
   . /usr/share/bash-completion/bash_completion\n' >> ~/.bashrc

WORKDIR /playbook
CMD bash
