FROM busybox
RUN wget https://github.com/gohugoio/hugo/releases/download/v0.81.0/hugo_0.81.0_Linux-64bit.tar.gz
RUN tar -xf hugo_*.tar.gz && mv hugo /bin/hugo && rm -rf hugo_*.tar.gz
WORKDIR /hugo
ENTRYPOINT ["/bin/hugo"]
