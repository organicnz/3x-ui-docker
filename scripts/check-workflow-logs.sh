#!/bin/bash

# Script to check GitHub Actions workflow logs for errors
# Usage: ./check-workflow-logs.sh [--latest] [--workflow-id=<id>] [--run-id=<id>]

set -e

# Default values
LATEST=true
WORKFLOW_ID=""
RUN_ID=""
REPO=""
OWNER=""

# Load environment variables
if [ -f ".env" ]; then
  source .env
else
  echo "Error: .env file not found. Please create it with GITHUB_TOKEN and other required variables."
  exit 1
fi

# Check for GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN environment variable not set. Please set it in your .env file."
  exit 1
fi

# Parse repository information from git remote
if [ -z "$REPO" ] || [ -z "$OWNER" ]; then
  REMOTE_URL=$(git config --get remote.origin.url)
  if [[ $REMOTE_URL =~ github.com[/:]([^/]+)/([^/.]+) ]]; then
    OWNER=${BASH_REMATCH[1]}
    REPO=${BASH_REMATCH[2]}
  else
    echo "Error: Unable to determine GitHub repository owner and name."
    echo "Please manually specify OWNER and REPO in your .env file."
    exit 1
  fi
fi

# Parse arguments
for arg in "$@"; do
  case $arg in
    --latest)
      LATEST=true
      shift
      ;;
    --workflow-id=*)
      WORKFLOW_ID="${arg#*=}"
      LATEST=false
      shift
      ;;
    --run-id=*)
      RUN_ID="${arg#*=}"
      LATEST=false
      shift
      ;;
    --help)
      echo "Usage: ./check-workflow-logs.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --latest            Check logs from the latest workflow run (default)"
      echo "  --workflow-id=<id>  Check logs from a specific workflow ID"
      echo "  --run-id=<id>       Check logs from a specific run ID"
      echo "  --help              Show this help message"
      exit 0
      ;;
  esac
done

echo "🔍 Checking GitHub Actions workflow logs for ${OWNER}/${REPO}..."

# Function to get latest workflow run
get_latest_workflow_run() {
  echo "📋 Fetching latest workflow run..."
  
  LATEST_RUN=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${OWNER}/${REPO}/actions/runs?per_page=1" | jq -r '.workflow_runs[0]')
  
  if [ "$LATEST_RUN" = "null" ] || [ -z "$LATEST_RUN" ]; then
    echo "❌ No workflow runs found!"
    exit 1
  fi
  
  RUN_ID=$(echo $LATEST_RUN | jq -r '.id')
  WORKFLOW_NAME=$(echo $LATEST_RUN | jq -r '.name')
  WORKFLOW_STATUS=$(echo $LATEST_RUN | jq -r '.status')
  WORKFLOW_CONCLUSION=$(echo $LATEST_RUN | jq -r '.conclusion')
  WORKFLOW_URL=$(echo $LATEST_RUN | jq -r '.html_url')
  
  echo "✅ Latest workflow run found:"
  echo "   Name: ${WORKFLOW_NAME}"
  echo "   ID: ${RUN_ID}"
  echo "   Status: ${WORKFLOW_STATUS}"
  echo "   Conclusion: ${WORKFLOW_CONCLUSION}"
  echo "   URL: ${WORKFLOW_URL}"
}

# Function to get specific workflow run
get_specific_workflow_run() {
  if [ -n "$RUN_ID" ]; then
    echo "📋 Fetching workflow run #${RUN_ID}..."
    
    RUN_INFO=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
      "https://api.github.com/repos/${OWNER}/${REPO}/actions/runs/${RUN_ID}")
    
    if [ "$(echo $RUN_INFO | jq -r '.message')" = "Not Found" ]; then
      echo "❌ Workflow run #${RUN_ID} not found!"
      exit 1
    fi
    
    WORKFLOW_NAME=$(echo $RUN_INFO | jq -r '.name')
    WORKFLOW_STATUS=$(echo $RUN_INFO | jq -r '.status')
    WORKFLOW_CONCLUSION=$(echo $RUN_INFO | jq -r '.conclusion')
    WORKFLOW_URL=$(echo $RUN_INFO | jq -r '.html_url')
    
    echo "✅ Workflow run #${RUN_ID} found:"
    echo "   Name: ${WORKFLOW_NAME}"
    echo "   Status: ${WORKFLOW_STATUS}"
    echo "   Conclusion: ${WORKFLOW_CONCLUSION}"
    echo "   URL: ${WORKFLOW_URL}"
  else
    echo "❌ No run ID specified!"
    exit 1
  fi
}

# Function to fetch job logs
fetch_job_logs() {
  echo "📥 Fetching job logs for run #${RUN_ID}..."
  
  JOBS=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${OWNER}/${REPO}/actions/runs/${RUN_ID}/jobs")
  
  JOBS_COUNT=$(echo $JOBS | jq -r '.total_count')
  
  if [ "$JOBS_COUNT" -eq 0 ]; then
    echo "❌ No jobs found for this workflow run!"
    exit 1
  fi
  
  echo "📋 Found ${JOBS_COUNT} jobs in this workflow run."
  
  # Create logs directory if it doesn't exist
  mkdir -p "workflow_logs/run-${RUN_ID}"
  
  # Create a symlink to the latest run
  rm -f workflow_logs/run-latest
  ln -sf "run-${RUN_ID}" workflow_logs/run-latest
  
  # Save individual job logs
  echo $JOBS | jq -c '.jobs[]' | while read -r job; do
    JOB_NAME=$(echo $job | jq -r '.name')
    JOB_ID=$(echo $job | jq -r '.id')
    JOB_STATUS=$(echo $job | jq -r '.status')
    JOB_CONCLUSION=$(echo $job | jq -r '.conclusion')
    JOB_STEPS=$(echo $job | jq -r '.steps | length')
    
    # Create a sanitized filename
    JOB_NAME_SAFE=$(echo $JOB_NAME | tr -cd '[:alnum:]._-')
    LOG_DIR="workflow_logs/run-${RUN_ID}/${JOB_NAME_SAFE}"
    mkdir -p "$LOG_DIR"
    
    echo "   Job: ${JOB_NAME} (${JOB_STATUS}/${JOB_CONCLUSION})"
    
    # Get job logs
    JOB_LOGS=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
      "https://api.github.com/repos/${OWNER}/${REPO}/actions/jobs/${JOB_ID}/logs")
    
    if [ "${#JOB_LOGS}" -gt 0 ]; then
      echo "$JOB_LOGS" > "${LOG_DIR}/full.log"
      
      # Extract errors from logs
      grep -i -E "error:|exception:|failed:|fatal:|panic:" "${LOG_DIR}/full.log" > "${LOG_DIR}/errors.log" || true
      
      ERROR_COUNT=$(wc -l < "${LOG_DIR}/errors.log")
      if [ "$ERROR_COUNT" -gt 0 ]; then
        echo "   ⚠️  Found ${ERROR_COUNT} errors in job logs"
      else
        echo "   ✅ No errors found in job logs"
      fi
    else
      echo "   ⚠️  Could not retrieve logs for this job"
    fi
  done
}

# Function to display summary
display_summary() {
  echo ""
  echo "📊 Workflow run summary:"
  echo "   Run ID: ${RUN_ID}"
  echo "   Status: ${WORKFLOW_STATUS}"
  echo "   Conclusion: ${WORKFLOW_CONCLUSION}"
  echo ""
  
  # Check if there are any failed jobs
  if [ -d "workflow_logs/run-${RUN_ID}" ]; then
    FAILED_JOBS=0
    TOTAL_ERRORS=0
    
    for job_dir in workflow_logs/run-${RUN_ID}/*; do
      if [ -f "${job_dir}/errors.log" ]; then
        ERROR_COUNT=$(wc -l < "${job_dir}/errors.log")
        TOTAL_ERRORS=$((TOTAL_ERRORS + ERROR_COUNT))
        
        if [ "$ERROR_COUNT" -gt 0 ]; then
          FAILED_JOBS=$((FAILED_JOBS + 1))
          JOB_NAME=$(basename "$job_dir")
          echo "⚠️  Job '${JOB_NAME}' has ${ERROR_COUNT} errors:"
          head -n 5 "${job_dir}/errors.log"
          
          if [ "$ERROR_COUNT" -gt 5 ]; then
            echo "   ... and $((ERROR_COUNT - 5)) more errors (see ${job_dir}/errors.log for full details)"
          fi
          
          echo ""
        fi
      fi
    done
    
    if [ "$FAILED_JOBS" -eq 0 ]; then
      echo "✅ All jobs completed successfully!"
    else
      echo "⚠️  ${FAILED_JOBS} jobs had errors with a total of ${TOTAL_ERRORS} errors."
      echo "   Full logs are available in: workflow_logs/run-${RUN_ID}/"
      echo "   Or use: workflow_logs/run-latest/ for convenience"
    fi
  fi
  
  echo ""
  echo "🔗 View full details in the GitHub Actions UI:"
  echo "   ${WORKFLOW_URL}"
}

# Main execution
if [ "$LATEST" = true ]; then
  get_latest_workflow_run
else
  get_specific_workflow_run
fi

fetch_job_logs
display_summary

echo "✅ Workflow logs check completed!" 