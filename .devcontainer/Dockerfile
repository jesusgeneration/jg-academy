# Keep this aligned with .ruby-version; the production Dockerfile is independent.
ARG RUBY_VERSION=4.0.5
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Set PATH in the image, not just an interactive shell: T3 launches providers
# and terminals without sourcing the user's shell initialization files.
ENV PATH="/home/vscode/.t3/cli:/home/vscode/.opencode/bin:/home/vscode/.local/share/mise/shims:/home/vscode/.local/bin:${PATH}"
