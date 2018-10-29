FROM node:8.11.1
RUN npm -g config set user root
RUN npm install -g composer-cli@0.19.13 
RUN npm install -g generator-hyperledger-composer@0.19.13 
RUN npm install -g composer-playground@0.19.13 
RUN npm install -g composer-rest-server@0.19.13
RUN npm install -g yo && \
    npm cache clean --force && \
    ln -s node_modules .node_modules \
