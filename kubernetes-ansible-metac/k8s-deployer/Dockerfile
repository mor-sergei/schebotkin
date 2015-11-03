FROM ciscocloud/deploytools
MAINTAINER Alexander Litvinenko <olytvyne@cisco.com>

COPY deploytools /deploytools/
WORKDIR /deploytools
RUN chmod +x *.sh *.py && \
mkdir /.private && \
adduser -S deployer && \
chown -R deployer /.private pre-deploy post-deploy

USER deployer

ENTRYPOINT ["/deploytools/envhelper.py"]
CMD ["-t","/deploytools/deploy.sh"]
