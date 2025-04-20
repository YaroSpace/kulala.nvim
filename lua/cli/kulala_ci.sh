install_dependencies() {
  echo "Installing JQ ===================================="
  yes | apt-get install jq

  # curl, grpcurl, websocat
}

echo "RUNNING KULALA CI ===================================="
install_dependencies
export PATH=$PATH:$GITHUB_WORKSPACE/kulala.nvim/lua/cli
