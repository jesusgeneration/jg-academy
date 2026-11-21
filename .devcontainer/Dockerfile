# Bootstrap from the published Rails image until its Ruby 4.0.10 image exists.
FROM ghcr.io/rails/devcontainer/images/ruby:4.0.5

# Keep the active Ruby aligned with .ruby-version and the production Dockerfile.
ARG RUBY_VERSION=4.0.10
USER vscode
RUN /home/vscode/.local/bin/mise install "ruby@${RUBY_VERSION}" && \
    /home/vscode/.local/bin/mise use --global "ruby@${RUBY_VERSION}"
USER root

# Select the updated Ruby for root and non-interactive container commands too.
ENV PATH="/home/vscode/.local/share/mise/installs/ruby/${RUBY_VERSION}/bin:${PATH}"
