FROM ghcr.io/autowarefoundation/autoware:latest-devel

# Install dependencies
RUN apt-get update \
    && apt-get install -y \
      sudo \
      ninja-build \
      rsync \
      gdb \
      gdbserver \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install llvm 16
RUN git clone https://gist.github.com/96573409aee8d12951337621ef07b027.git /tmp/install-llvm \
&& chmod +x /tmp/install-llvm/install.sh \
&& /tmp/install-llvm/install.sh 16 \
&& rm -rf /tmp/install-llvm

# Arguments.
ARG USERNAME=nonroot
ARG UID=1000
ARG GID=1000

# Environment variables.
ENV USERNAME=$USERNAME
ENV UID=$UID
ENV GID=$GID

# Create the user.
RUN groupadd --gid $GID $USERNAME \
&& adduser \
  --disabled-password \
  --disabled-login \
  --gecos "" \
  --uid $UID \
  --gid $GID \
  $USERNAME \
&& usermod -aG sudo $USERNAME \
&& groups $USERNAME \
&& echo "$USERNAME ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/$USERNAME

# Create /workspaces folder owned by nonroot.
RUN mkdir /workspaces && chown $USERNAME:$USERNAME /workspaces
VOLUME /workspaces
WORKDIR /workspaces

# Set the default user.
USER $USERNAME

# Install Zsh and Oh My Zsh.
RUN git clone https://gist.github.com/fe0d401310134bb6012beb3627c367ee.git /tmp/install-zsh \
&& sudo chmod +x /tmp/install-zsh/install.sh \
&& /tmp/install-zsh/install.sh \
&& sudo rm -rf /tmp/install-zsh

# Add ROS underlay packages and auto-completion
RUN  echo -e "# ROS" >> $HOME/.bashrc \
  && echo -e "source /opt/ros/humble/setup.bash" >> $HOME/.bashrc \
  && echo -e "source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash" >> $HOME/.bashrc \
  && echo -e "export RCUTILS_COLORIZED_OUTPUT=1" >> $HOME/.bashrc \
  && echo -e "export GTEST_COLOR=1" >> $HOME/.bashrc \
  && echo -e "# ROS" >> $HOME/.zshrc \
  && echo -e "source /opt/ros/humble/setup.zsh" >> $HOME/.zshrc \
  && echo -e 'eval "$(register-python-argcomplete3 ros2)"' >> $HOME/.zshrc \
  && echo -e 'eval "$(register-python-argcomplete3 colcon)"' >> $HOME/.zshrc \
  && echo -e "export RCUTILS_COLORIZED_OUTPUT=1" >> $HOME/.zshrc \
  && echo -e "export GTEST_COLOR=1" >> $HOME/.zshrc \
  && rosdep update

# Export local binaries to PATH.
RUN  echo -e "export PATH=$HOME/.local/bin:$PATH" >> $HOME/.bashrc \
  && echo -e "export PATH=$HOME/.local/bin:$PATH" >> $HOME/.zshrc

# Install ansible for downloading data.
RUN sudo apt-get update \
  && sudo apt-get purge ansible \
  && sudo apt-get -y update \
  && sudo apt-get -y install pipx \
  && python3 -m pipx ensurepath \
  && pipx install --include-deps --force "ansible==6.*" \
  && sudo apt-get autoremove -y \
  && sudo apt-get clean -y \
  && sudo rm -rf /var/lib/apt/lists/*

# Install ccache
# https://autowarefoundation.github.io/autoware-documentation/main/how-to-guides/others/advanced-usage-of-colcon/#using-ccache-to-speed-up-recompilation
RUN  sudo apt-get update \
  && sudo apt-get install -y ccache \
  && mkdir -p $HOME/.cache/ccache \
  && touch $HOME/.cache/ccache/ccache.conf \
  && echo -e "max_size = 60G" >> $HOME/.cache/ccache/ccache.conf \
  && echo -e 'export CC="/usr/lib/ccache/gcc"' >> $HOME/.bashrc \
  && echo -e 'export CXX="/usr/lib/ccache/g++"' >> $HOME/.bashrc \
  && echo -e 'export CCACHE_DIR="$HOME/.cache/ccache/"' >> $HOME/.bashrc \
  && echo -e 'export CC="/usr/lib/ccache/gcc"' >> $HOME/.zshrc \
  && echo -e 'export CXX="/usr/lib/ccache/g++"' >> $HOME/.zshrc \
  && echo -e 'export CCACHE_DIR="$HOME/.cache/ccache/"' >> $HOME/.zshrc

# Start zsh shell when the container starts
ENTRYPOINT [ "zsh" ]
CMD ["-l"]
