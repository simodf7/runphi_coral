FROM ubuntu:22.04

RUN apt-get update

ENV TZ=America/Los_Angeles

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get install -y vim git make sed binutils diffutils python3 ninja-build build-essential bzip2 tar findutils unzip cmake

RUN apt-get install -y rsync libglib2.0-dev libpixman-1-dev wget cpio rsync bc libncurses5 libncurses5-dev flex bison openssl libssl-dev kmod python3-pip file pkg-config rsync u-boot-tools 

RUN apt-get install -y gcc-arm-none-eabi gcc-aarch64-linux-gnu

RUN pip3 install Mako

ENV TERM=xterm-256color

RUN echo "PS1='\[\e[38;5;39m\]\w\[\e[0m\] \[\e[38;5;46;1m\]>\[\e[0m\] '" >> /root/.bashrc

RUN echo "source /root/.bashrc" >> /root/.profile

ENV HOME=/home
#RUN source /root/.bashrc
# Set the entry point to source .bashrc and start bash

CMD ["bash", "-c", "source /root/.bashrc && exec /bin/bash -il"]

#RUN source /root/.bashrc
