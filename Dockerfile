FROM fedora 

#########################################
##        BUILD-TIME VARIABLES        ##
#########################################
# url for Network Licence Manager
ARG NLM_URL=https://damassets.autodesk.net/content/dam/autodesk/www/files/linux/nlm11-19-4-1-ipv4-ipv6-linux64.tar.gz
# path for temporary files
ARG TEMP_PATH=/tmp/flexnetserver

#########################################
##        ENVIRONMENTAL CONFIG         ##
#########################################
# add the flexlm commands to $PATH
ENV PATH="$PATH:/opt/flexnetserver/"

#########################################
##         RUN INSTALL SCRIPT          ##
#########################################
COPY /files /usr/local/bin

RUN dnf install -y redhat-lsb-core wget && yum clean all

WORKDIR $TEMP_PATH
RUN wget --progress=bar:force -- $NLM_URL
RUN tar -zxvf ./*.tar.gz
RUN rpm -vhi ./*.rpm
RUN rm -rf $TEMP_PATH

# lmadmin is required for -2 -p flag support
RUN groupadd -r lmadmin && \
    useradd -r -g lmadmin lmadmin

#########################################
##              VOLUMES                ##
#########################################
VOLUME ["/var/flexlm"]

#########################################
##            EXPOSE PORTS             ##
#########################################
EXPOSE 2080
EXPOSE 27000-27009

# do not use ROOT user
USER lmadmin

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# no CMD, use container as if 'lmgrd'
