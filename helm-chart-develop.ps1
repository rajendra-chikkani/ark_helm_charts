# Function to parse the script arguments
function Parse-ScriptArguments {
    param (
        [string[]]$Arguments
    )

    for ($i = 0; $i -lt $Arguments.Length; $i++) {
        if ($Arguments[$i] -eq "-helm-branch" -and $i + 1 -lt $Arguments.Length) {
            return $Arguments[$i + 1]
        }
    }

    return $null
}

# Function to check if a branch name was provided
function Check-BranchNameProvided {
    param (
        [string]$Branch
    )

    if (-not $Branch) {
        Write-Host "Please provide a branch name using '-helm-branch' argument."
        exit 1
    }
}

# Function to deploy Helm chart
function Deploy-HelmChart {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName
    )

    # Set the Git repository URL
    $gitRepository = "https://github.com/rajendra-chikkani/ark_helm_charts"

    # Clone the Git repository to a specific directory using the Git command
    $cloneDirectory = "arkcase/app"
    git clone $gitRepository $cloneDirectory
    Set-Location $cloneDirectory

    # Fetch branch names from the remote repository
    git fetch -q

    # Get the current branch name
    $gitBranch = git rev-parse --abbrev-ref HEAD

    if ($gitBranch -eq "main") {
        $environment = "prod"
        $valuesFile = "values-$environment.yaml"
    } elseif ($gitBranch -eq "feature/memspec") {
        $environment = "dev"
        $valuesFile = "values-dev.yaml"
    } else {
        $environment = $BranchName.ToLower()
        $valuesFile = "values-dev.yaml"
    }

    # Check if the specified branch exists in the repository
    $remoteBranch = "origin/$BranchName"

    if (git branch --list --remote $remoteBranch -q) {
        # Switch to the specified Git branch
        git checkout $remoteBranch -q

        # Determine the environment and values file based on the Git branch
        if ($BranchName -eq "feature/memspec") {
            $environment = "dev"
            $valuesFile = "values-dev.yaml"
        } elseif ($BranchName -eq "main") {
            $environment = "prod"
            $valuesFile = "values-$environment.yaml"
        } else {
            $environment = $BranchName.ToLower()
            $valuesFile = "values-dev.yaml"
        }

        # Set the chart path
        $chartPath = $PWD.Path

        # Verify if the values file exists in the specified location
        $valuesFilePath = Join-Path -Path $chartPath -ChildPath $valuesFile
        if (-not (Test-Path -Path $valuesFilePath)) {
            Write-Host "Values file '$valuesFile' not found in the chart directory."
            exit 1
        }
    } else {
        Write-Host "Branch '$BranchName' not found in the remote repository."
        exit 1
    }

    # Display the determined environment
    Write-Host ""
    Write-Host "Environment: $environment"
    Write-Host ""
    Write-Host "Current directory: $chartPath"
    Write-Host ""
    $releaseName = "arkcase"

    Set-Location src/app

    # Run Helm command to deploy the chart
    helm install $releaseName . --values $valuesFilePath
    Write-Host ""
}

# Parse the script arguments
$BranchName = Parse-ScriptArguments -Arguments $args

# Check if a branch name was provided
Check-BranchNameProvided -Branch $BranchName

# Call the function and pass the Git branch as an argument
Deploy-HelmChart -BranchName $BranchName
