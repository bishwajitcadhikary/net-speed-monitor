#!/bin/bash

# Test GitHub Actions workflows using act
# Usage: ./scripts/test-workflows.sh [workflow_name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 GitHub Actions Workflow Tester${NC}"
echo "=================================="

# Check if act is installed
if ! command -v act &> /dev/null; then
    echo -e "${RED}❌ act is not installed. Please install it first:${NC}"
    echo "   brew install act"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "project.yml" ]; then
    echo -e "${RED}❌ project.yml not found. Please run this script from the project root.${NC}"
    exit 1
fi

# Function to test a specific workflow
test_workflow() {
    local workflow_name=$1
    local event_type=$2
    
    echo -e "\n${YELLOW}🧪 Testing workflow: $workflow_name${NC}"
    echo "Event: $event_type"
    echo "----------------------------------------"
    
    if [ "$workflow_name" = "build-and-release" ]; then
        echo -e "${YELLOW}⚠️  Note: This workflow requires macOS and will be skipped by act${NC}"
        echo -e "${YELLOW}   It will work when pushed to GitHub with proper secrets${NC}"
        act workflow_dispatch --container-architecture linux/amd64 --dryrun
    else
        act $event_type --container-architecture linux/amd64
    fi
    
    echo -e "\n${GREEN}✅ Workflow test completed${NC}"
}

# Function to show available workflows
show_workflows() {
    echo -e "\n${BLUE}📋 Available workflows:${NC}"
    echo "1. build (macOS build - skipped by act)"
    echo "2. build-and-release (macOS release - skipped by act)"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ./scripts/test-workflows.sh build"
    echo "  ./scripts/test-workflows.sh build-and-release"
    echo "  ./scripts/test-workflows.sh all"
}

# Main logic
case "${1:-}" in
    "build")
        echo -e "${YELLOW}⚠️  Build workflow requires macOS and will be skipped by act${NC}"
        act pull_request --container-architecture linux/amd64 --dryrun
        ;;
    "build-and-release")
        test_workflow "build-and-release" "workflow_dispatch"
        ;;
    "all")
        echo -e "${BLUE}🔄 Testing all workflows...${NC}"
        echo -e "${YELLOW}⚠️  All workflows require macOS and will be skipped by act${NC}"
        act pull_request --container-architecture linux/amd64 --dryrun
        act workflow_dispatch --container-architecture linux/amd64 --dryrun
        ;;
    "")
        show_workflows
        ;;
    *)
        echo -e "${RED}❌ Unknown workflow: $1${NC}"
        show_workflows
        exit 1
        ;;
esac

echo -e "\n${GREEN}🎉 Workflow testing completed!${NC}"
echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "• macOS workflows will work when pushed to GitHub"
echo "• Set up secrets in GitHub for release workflow"
echo "• See docs/GITHUB_ACTIONS_SETUP.md for detailed instructions"
