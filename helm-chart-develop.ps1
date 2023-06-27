# Set the Git repository URL
$gitRepository = "https://github.com/ArkCase/ark_helm_charts"

# Clone the Git repository to a specific directory using the Git command
$cloneDirectory = "./mychart"
git clone $gitRepository $cloneDirectory

# Get the current Git branch
$gitBranch = git rev-parse --abbrev-ref HEAD

# Determine the environment and values file based on the Git branch
if ($gitBranch -eq "develop") {
    $environment = "dev"
    $valuesFile = "values-dev.yaml"
} elseif ($gitBranch -eq "main") {
    $environment = "prod"
    $valuesFile = "values-prod.yaml"
} else {
    Write-Host "Invalid branch."
    exit 1
}


# Prompt the user if an environment was not determined
if ($environment -eq $null) {
    $environment = Read-Host "Enter the environment (dev/main):"
    $valuesFile = "values-$environment.yaml"
}

# Display the determined environment
Write-Host "Environment: $environment"

# Set the chart path
$chartPath = $cloneDirectory
$releaseName = "mychart-release"

# Run Helm command to deploy the chart
helm install --name $releaseName --values $valuesFile $chartPath
