alias tf='terraform'
alias k='kubectl'
alias kca='f(){ kubectl "$@" --all-namespaces -o wide;  unset -f f; }; f'

alias argo-secret='kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo'
alias pod-limits='kubectl get po -o custom-columns="Name:metadata.name,CPU-limit:spec.containers[*].resources.limits.cpu, CPU-request:spec.containers[*].resources.requests.cpu, memory-limits:spec.containers[*].resources.limits.memory, memory-request:spec.containers[*].resources.requests.memory"'

alias ssh-rancher='function _ssh_from_json() {
    json_file=$1
    folder_path=$(dirname "$json_file")
    ip=$(jq -r ".IPAddress" $json_file)
    user=$(jq -r ".SSHUser" $json_file)
    port=$(jq -r ".SSHPort" $json_file)
    machine=$(jq -r ".MachineName" $json_file)
    chmod 600 $folder_path/id_rsa
    echo "Connecting to $machine ($ip) as $user on port $port"
    ssh -i $folder_path/id_rsa -p $port $user@$ip
}; _ssh_from_json'


pod-resources() {
  # Function to get the current namespace if no namespace is provided
  get_current_namespace() {
    kubectl config view --minify --output 'jsonpath={..namespace}'
  }

  # Check if a namespace is passed as an argument
  if [ -z "$1" ]; then
    namespace=$(get_current_namespace)
    if [ -z "$namespace" ]; then
      namespace="default"
    fi
  else
    namespace=$1
  fi

  echo "Using namespace: $namespace"

  # Get the resource requests and limits for the specified namespace
  kubectl get pods -n $namespace -o json > requests_limits.json

  # Get the current resource utilization for the specified namespace
  kubectl top pod -n $namespace --containers > utilization.txt

  # Process the utilization and compare with requests and limits
  while IFS= read -r line
  do
    # Skip the header line
    if [[ $line == *"NAMESPACE"* ]]; then
      continue
    fi
    if [[ $line == *"POD"* ]]; then
      continue
    fi

    # Extract data from each line
    pod=$(echo $line | awk '{print $1}')
    container=$(echo $line | awk '{print $2}')
    cpu_usage=$(echo $line | awk '{print $3}')
    memory_usage=$(echo $line | awk '{print $4}')

    # Convert usage from string to numeric values
    cpu_usage_value=$(echo $cpu_usage | sed 's/m//')  # Remove 'm' from CPU usage
    memory_usage_value=$(echo $memory_usage | sed 's/Mi//')  # Remove 'Mi' from memory usage

    # Find the corresponding requests in the JSON
    cpu_request=$(jq -r --arg pod "$pod" --arg container "$container" \
    '.items[] | select(.metadata.name==$pod) | .spec.containers[] | select(.name==$container) | .resources.requests.cpu' requests_limits.json)
    
    memory_request=$(jq -r --arg pod "$pod" --arg container "$container" \
    '.items[] | select(.metadata.name==$pod) | .spec.containers[] | select(.name==$container) | .resources.requests.memory' requests_limits.json)

    # Convert requests from string to numeric values
    cpu_request_value=$(echo $cpu_request | sed 's/m//')
    memory_request_value=$(echo $memory_request | sed 's/Mi//')


    echo "Namespace: $namespace, Pod: $pod, Container: $container"
    echo "CPU Usage: ${cpu_usage} /${cpu_request}"
    echo "Memory Usage: ${memory_usage} /${memory_request} "
    echo "--------------------------------------------"

  done < utilization.txt

  # Clean up
  rm requests_limits.json utilization.txt
}





