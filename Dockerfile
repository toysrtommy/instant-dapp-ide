FROM ubuntu:trusty
MAINTAINER dominicwilliams

ENV DEBIAN_FRONTEND noninteractive

RUN echo "Rebuilding from here: cache bust 23u42324"

RUN apt-get update
RUN apt-get upgrade -q -y
RUN apt-get dist-upgrade -q -y

RUN apt-get install -y figlet
RUN apt-get install -y strace
RUN apt-get install -y curl
RUN apt-get install -y vim
RUN apt-get install -y git

RUN curl -sL https://deb.nodesource.com/setup_5.x | sudo -E bash -
RUN apt-get install -y nodejs
RUN apt-get install -y python
RUN apt-get install -y python-pip
RUN apt-get install -y python-dev
RUN apt-get install -y libssl-dev
RUN apt-get install -y rake

# Install tmux to gain split screen management and screen sharing capabilities
RUN apt-get install -y tmux

# Pimp VIM with Nerd Tree and other goodies using the Braintree setup
WORKDIR /root
RUN git clone https://github.com/braintreeps/vim_dotfiles.git
WORKDIR /root/vim_dotfiles
RUN rake

# Add TypeScrupt support too
RUN echo "Plug 'leafgarland/typescript-vim'" >> /root/.vimrc.bundles.local
WORKDIR /root/.vim/plugged
RUN git clone https://github.com/leafgarland/typescript-vim.git typescript-vim

# Make sure we are using 
RUN echo 'set encoding=utf-8' >> /root/.vimrc

# Configure VIM with support for Solidity
WORKDIR /root/.vim
RUN curl -o vim-solidity-master.zip https://codeload.github.com/tomlion/vim-solidity/zip/master
RUN unzip vim-solidity-master.zip
RUN mv vim-solidity-master/* .

# Add an SSH server for social hacking i.e. pair/multi programming and configure run on port 2222
RUN apt-get install -y openssh-server
RUN sed -i '/Port 22/c\Port 2222' /etc/ssh/sshd_config
RUN sed -i '/LogLevel INFO/c\LogLevel VERBOSE' /etc/ssh/sshd_config
RUN sed -i '/PasswordAuthentication yes/c\PasswordAuthentication no' /etc/ssh/sshd_config 
RUN mkdir /var/run/sshd
RUN mkdir /root/.ssh

# Add Cloud9 for pair programming & IDE, in addition to tmux
WORKDIR /opt
RUN git clone git://github.com/c9/core.git cloud9
WORKDIR /opt/cloud9
RUN scripts/install-sdk.sh
# patch for solidty syntax
ADD patches/c9/node_modules/ace/lib/ace/ext/modelist.js /opt/cloud9/node_modules/ace/lib/ace/ext/modelist.js
ADD patches/c9/node_modules/ace/lib/ace/mode/solidity.js /opt/cloud9/node_modules/ace/lib/ace/mode/solidity.js
ADD patches/c9/node_modules/ace/lib/ace/mode/solidity_highlight_rules.js /opt/cloud9/node_modules/ace/lib/ace/mode/solidity_highlight_rules.js
ADD patches/c9/node_modules/ace/lib/ace/snippets/solidity.js /opt/cloud9/node_modules/ace/lib/ace/snippets/solidity.js
# make C9 server runnable (user needs to run $ c9.sh to launch platform)
RUN mkdir /opt/cloud9/workspace
WORKDIR /opt/cloud9/workspace
RUN ln -s /src src
RUN echo 'cd /opt/cloud9;node server.js --collab -p 8181  --listen 0.0.0.0 -a : -w /opt/cloud9/workspace' > /usr/local/bin/c9.sh
RUN chmod ugo+x /usr/local/bin/c9.sh

# Install testrpc and Truffle directly from github as PIP and NPM not regularly
# updated (e.g. make sure we have latest version solc)
# ethereumjs-testrpc
WORKDIR /tmp
RUN git clone https://github.com/ethereumjs/testrpc.git
WORKDIR /tmp/testrpc
RUN npm install -g .
# Truffle
WORKDIR /tmp
RUN git clone https://github.com/ConsenSys/truffle-default-builder.git
WORKDIR /tmp/truffle-default-builder
RUN npm install -g .
RUN echo "Rebuilding from here: cache bust 32432"
WORKDIR /tmp
RUN git clone https://github.com/ConsenSys/truffle.git
WORKDIR /tmp/truffle
RUN npm install -g .

# Create an instructive welcome message
RUN echo 'figlet Instant Dapp IDE' >> /root/.bashrc
RUN echo 'echo "\n\
 Build 2016-02-29.2\n\
 \n\
 NOTE: tmux is used to maintain concurrent windows. In window 0 we are running\n\
 testrpc, which is a dummy blockchain for testing and development. In window 1\n\
 we are running c9.sh, which makes the Cloud9 IDE available in a Web browser on\n\
 http://localhost:8181. You are in window 2, which is a great place to manage\n\
 your Dapp. Note you can create a new window using ctrl-b c, and you can\n\
 navigate to an existing window using ctrl-b <window>.\n\
 \n\
 GET STARTED\n\
 $ cd /src                # make external source code folder current directory\n\
 $ mkdir new-proj         # create a new project folder\n\
 $ cd new-proj            # make project folder current directory\n\
 $ truffle init           # initialize a bare bones project!!!\n\
 $ truffle test           # run project'"'s"' unit tests\n\
 $ truffle build          # build the whole Dapp (inc. html, js...)\n\
 $ truffle deploy         # deploy compiled contracts to testrpc chain\n\
 $ ctrl-b c               # create window 3...\n\
 $ truffle serve          # serve Dapp for testing on http://localhost:8080\n\
 $ ctrl-b 2               # return window 2\n\
 \n\
 TIPS\n\
 -- Share your Cloud9 url with collaborators (via external IP)\n\
 ---- Cloud9 supports real time shared editing of code\n\
 -- If you prefer using the terminal we have installed VIM\n\
 ---- Ready pimped with NerdTree and Solidity support\n\
 -- SSH server is installed for sharing the command line\n\
 ---- Pairs join tmux sessions using $ tmux a -t pair\n\
 \n\
 DOCS\n\
 -- https://media.readthedocs.org/pdf/solidity/latest/solidity.pdf\n\
 -- https://github.com/ConsenSys/truffle\n\
 -- https://gist.github.com/MohamedAlaa/2961058 [tmux]\n\
 \n\
 Enjoy! Ping me with feature requests via https://twitter.com/dominic_w\n\
"' >> /root/.bashrc

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# On entry, start sshd, run system loggger, copy pair programming keys into authorized keys, and run bash
ENTRYPOINT service ssh start && rsyslogd && cp /root/.import/authorized_keys /root/.ssh/ && tmux new -s pair 'testrpc -d 0.0.0.0' \; new-window 'c9.sh' \; new-window 

# Start user in their source code directory...
WORKDIR /src

