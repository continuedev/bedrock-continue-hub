#!/bin/bash

# Script to update AWS Bedrock model blocks using cn CLI
# This script identifies missing models and creates the necessary block files

set -e

echo "🔍 Updating AWS Bedrock model blocks..."

# Get current version from existing YAML files and increment patch version
CURRENT_VERSION=$(grep -h "^version:" blocks/public/*.yaml | head -1 | cut -d' ' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.0.0"
fi

# Parse and increment patch version (semver)
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
NEW_VERSION="$major.$minor.$((patch + 1))"

echo "📦 Current version: $CURRENT_VERSION"
echo "📦 New version: $NEW_VERSION"

# Check what files currently exist
echo "🔍 Checking existing blocks..."
existing_files=$(ls blocks/public/*.yaml | sed 's|blocks/public/||' | sed 's|\.yaml||')

# Function to get available models from AWS Bedrock
get_online_models() {
    echo "🌐 Fetching available models from AWS Bedrock..."
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        echo "⚠️ AWS CLI not found, falling back to hardcoded model list"
        return 1
    fi
    
    # Try to fetch models, handle potential errors
    local models_json
    if models_json=$(aws bedrock list-foundation-models --region us-east-1 --output json 2>/dev/null); then
        # Extract model IDs from the response
        local online_models
        online_models=$(echo "$models_json" | jq -r '.modelSummaries[]?.modelId // empty' 2>/dev/null | sort)
        
        if [ -z "$online_models" ]; then
            echo "⚠️ No models returned from AWS API, falling back to hardcoded list"
            return 1
        fi
        
        echo "✅ Successfully fetched $(echo "$online_models" | wc -l) models from AWS Bedrock"
        echo "$online_models"
        return 0
    else
        echo "⚠️ Failed to fetch models from AWS Bedrock (check credentials/region), falling back to hardcoded list"
        return 1
    fi
}

# Function to convert model ID to file name
model_id_to_filename() {
    local model_id="$1"
    # Convert model ID to expected filename format
    # e.g., "anthropic.claude-3-haiku-20240307-v1:0" -> "anthropic-claude-3-haiku-20240307-v1-0"
    # Replace dots and colons with dashes for valid filenames
    echo "$model_id" | sed 's/\./-/g' | sed 's/:/-/g'
}

# Function to extract context length from model ID (only if explicit)
get_context_length() {
    local model_id="$1"
    # Extract context length only from explicit patterns like ":200k", ":100k", ":48k", etc.
    if [[ "$model_id" =~ :([0-9]+)k$ ]]; then
        echo $((${BASH_REMATCH[1]} * 1000))
    else
        # Return empty if no explicit context length
        echo ""
    fi
}

# Get expected models - try online first, fallback to hardcoded
if online_model_ids=$(get_online_models); then
    # Convert online model IDs to expected filenames
    expected_models=()
    while IFS= read -r model_id; do
        if [[ "$model_id" == anthropic.claude* ]] || [[ "$model_id" == openai.gpt-oss* ]]; then
            if filename=$(model_id_to_filename "$model_id"); then
                expected_models+=("$filename")
            fi
        fi
    done <<< "$online_model_ids"
    
    echo "📋 Found ${#expected_models[@]} relevant models online: ${expected_models[*]}"
else
    # Fallback to hardcoded list
    echo "📋 Using hardcoded model list"
    expected_models=(
        "anthropic-claude-3-haiku"
        "anthropic-claude-3-opus"
        "anthropic-claude-3-sonnet"
        "anthropic-claude-3-5-haiku"
        "anthropic-claude-3-5-sonnet-v1"
        "anthropic-claude-3-5-sonnet-v2"
        "anthropic-claude-3-7-sonnet"
        "anthropic-claude-opus-4"
        "anthropic-claude-opus-4-1"
        "anthropic-claude-sonnet-4"
        "openai-gpt-oss-120b"
        "openai-gpt-oss-20b"
    )
fi

# Function to check if model ID already exists in any file
model_id_exists() {
    local model_id="$1"
    # Check if any existing YAML file contains this model ID
    for yaml_file in blocks/public/*.yaml; do
        if [[ -f "$yaml_file" ]] && grep -q "model: $model_id" "$yaml_file" 2>/dev/null; then
            return 0  # Model ID exists
        fi
    done
    return 1  # Model ID doesn't exist
}

# Find missing models
missing_models=()
for model in "${expected_models[@]}"; do
    if ! echo "$existing_files" | grep -q "^${model}$"; then
        # Also check if the actual model ID already exists in another file
        model_info=$(get_model_details "$model")
        if [[ -n "$model_info" ]]; then
            IFS='|' read -r model_name model_id supports_tools context_length <<< "$model_info"
            if ! model_id_exists "$model_id"; then
                missing_models+=("$model")
            else
                echo "⏭️  Skipping $model - model ID $model_id already exists in another file"
            fi
        fi
    fi
done

if [ ${#missing_models[@]} -eq 0 ]; then
    echo "✅ No missing models found"
    
    # Check if existing models need tool_use capability added
    echo "🔍 Checking for missing tool_use capabilities..."
    
    models_needing_tools=()
    for yaml_file in blocks/public/*.yaml; do
        if [[ "$yaml_file" == *"anthropic"* ]] || [[ "$yaml_file" == *"openai"* ]]; then
            if ! grep -q "tool_use" "$yaml_file"; then
                models_needing_tools+=("$yaml_file")
            fi
        fi
    done
    
    if [ ${#models_needing_tools[@]} -eq 0 ]; then
        echo "✅ All existing models already have proper capabilities"
        exit 0
    fi
    
    echo "📋 Adding tool_use capability to ${#models_needing_tools[@]} existing models..."
    
    # Update existing models to add tool_use capability
    for yaml_file in "${models_needing_tools[@]}"; do
        model_name=$(basename "$yaml_file" .yaml)
        echo "Updating capabilities for: $model_name"
        
        cn -p --silent --allow Write --allow Edit << EOF
Read the file $yaml_file and add tool_use capability to it.

The file should have this structure with tool_use capability added:

1. Update version to $NEW_VERSION
2. Add capabilities section with tool_use if missing

The YAML should look like:
name: [existing name]
version: $NEW_VERSION
schema: v1

models:
  - name: [existing name]
    provider: bedrock
    model: [existing model id]
    env:
      region: \${{ inputs.BEDROCK_AWS_REGION }}
      profile: \${{ inputs.BEDROCK_AWS_PROFILE }}
    roles:
      - chat
      - apply
      - edit
    capabilities:
      - tool_use

Update the file now. Preserve all existing content, just update version and add capabilities.
EOF

        if [ $? -eq 0 ]; then
            echo "✅ Updated $yaml_file"
        else
            echo "❌ Failed to update $yaml_file"
        fi
    done
    
    # Commit the capability updates
    echo "📝 Committing capability updates..."
    git add "${models_needing_tools[@]}"
    git commit -m "Add tool_use capability to existing models

- Update all Anthropic Claude models to include tool_use capability
- Update all GPT-OSS models to include tool_use capability
- Bump version to $NEW_VERSION"
    
    echo "✅ Updated capabilities for ${#models_needing_tools[@]} models"
    exit 0
fi

echo "📋 Missing ${#missing_models[@]} models: ${missing_models[*]}"

# Define model details function
get_model_details() {
    local filename="$1"
    
    # If we have online model data, try to find the exact model ID
    if [[ -n "$online_model_ids" ]]; then
        # Look for matching model ID in online data
        local model_id
        while IFS= read -r id; do
            local converted_filename
            if converted_filename=$(model_id_to_filename "$id"); then
                if [[ "$converted_filename" == "$filename" ]]; then
                    model_id="$id"
                    break
                fi
            fi
        done <<< "$online_model_ids"
        
        if [[ -n "$model_id" ]]; then
            # Generate display name from filename
            local display_name
            display_name=$(echo "$filename" | sed 's/^anthropic-//' | sed 's/^openai-//' | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
            # Get context length if explicit
            local context_length
            context_length=$(get_context_length "$model_id")
            echo "$display_name|$model_id|yes|$context_length"
            return 0
        fi
    fi
    
    # Fallback to hardcoded mapping for known models
    # Extract context length from filename if present
    local context_length
    context_length=$(get_context_length "$filename")
    
    case "$filename" in
        "anthropic-claude-3-haiku") echo "Claude 3 Haiku|anthropic.claude-3-haiku-20240307-v1:0|yes|$context_length" ;;
        "anthropic-claude-3-opus") echo "Claude 3 Opus|anthropic.claude-3-opus-20240229-v1:0|yes|$context_length" ;;
        "anthropic-claude-3-sonnet") echo "Claude 3 Sonnet|anthropic.claude-3-sonnet-20240229-v1:0|yes|$context_length" ;;
        "anthropic-claude-3-5-haiku") echo "Claude 3.5 Haiku|anthropic.claude-3-5-haiku-20241022-v1:0|yes|$context_length" ;;
        "anthropic-claude-3-5-sonnet-v1") echo "Claude 3.5 Sonnet v1|anthropic.claude-3-5-sonnet-20240620-v1:0|yes|$context_length" ;;
        "anthropic-claude-3-5-sonnet-v2") echo "Claude 3.5 Sonnet v2|anthropic.claude-3-5-sonnet-20241022-v2:0|yes|$context_length" ;;
        "anthropic-claude-3-7-sonnet") echo "Claude 3.7 Sonnet|anthropic.claude-3-7-sonnet-20250219-v1:0|yes|$context_length" ;;
        "anthropic-claude-opus-4") echo "Claude Opus 4|anthropic.claude-opus-4-20250514-v1:0|yes|$context_length" ;;
        "anthropic-claude-opus-4-1") echo "Claude Opus 4.1|anthropic.claude-opus-4-1-20250805-v1:0|yes|$context_length" ;;
        "anthropic-claude-sonnet-4") echo "Claude Sonnet 4|anthropic.claude-sonnet-4-20250514-v1:0|yes|$context_length" ;;
        "openai-gpt-oss-120b") echo "GPT-OSS 120B|openai.gpt-oss-120b-1:0|yes|$context_length" ;;
        "openai-gpt-oss-20b") echo "GPT-OSS 20B|openai.gpt-oss-20b-1:0|yes|$context_length" ;;
        *) echo "" ;;
    esac
}

# Create each missing model block
echo "🏗️ Creating model blocks..."
created_files=()

for model_file in "${missing_models[@]}"; do
    model_info=$(get_model_details "$model_file")
    if [[ -n "$model_info" ]]; then
        IFS='|' read -r model_name model_id supports_tools context_length <<< "$model_info"
        filepath="blocks/public/${model_file}.yaml"
        
        echo "Creating block for: $model_name"
        
        # Build the YAML content
        yaml_content="name: $model_name
version: $NEW_VERSION
schema: v1

models:
  - name: $model_name
    provider: bedrock
    model: $model_id
    env:
      region: \${{ inputs.BEDROCK_AWS_REGION }}
      profile: \${{ inputs.BEDROCK_AWS_PROFILE }}
    roles:
      - chat
      - apply
      - edit"

        if [ "$supports_tools" = "yes" ]; then
            yaml_content="$yaml_content
    capabilities:
      - tool_use"
        fi

        if [ -n "$context_length" ] && [ "$context_length" != "" ]; then
            yaml_content="$yaml_content
    defaultCompletionOptions:
      contextLength: $context_length"
        fi

        cn -p --silent --allow Write --allow Edit << EOF
Create a single YAML file at $filepath for the model "$model_name" with ID "$model_id".

Use this exact format:

$yaml_content

Write this file now. Do not provide any other output.
EOF

        if [ $? -eq 0 ]; then
            echo "✅ Created $filepath"
            created_files+=("$filepath")
        else
            echo "❌ Failed to create $filepath"
        fi
    fi
done

# Commit all new files
if [ ${#created_files[@]} -gt 0 ]; then
    echo "📝 Committing new blocks..."
    git add "${created_files[@]}"
    git commit -m "Add missing AWS Bedrock model blocks

- Add missing Anthropic Claude models with tool_use capability
- Add missing GPT-OSS models with tool_use capability  
- Bump version to $NEW_VERSION"
    
    echo "✅ Committed ${#created_files[@]} new model blocks"
else
    echo "ℹ️ No new files to commit"
fi

echo "✅ Model blocks update completed!"