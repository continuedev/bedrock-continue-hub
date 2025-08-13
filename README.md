# @bedrock on hub.continue.dev

AWS Bedrock model blocks for Continue. These blocks provide access to Anthropic Claude models through AWS Bedrock with proper tool use capabilities and context length configurations.

## How to Use These Models

These blocks use [Continue's input system](https://docs.continue.dev/reference) with mustache templating (`${{ inputs.VARIABLE }}`) to configure AWS credentials dynamically.

### Required Inputs

All Bedrock models require two inputs:
- `BEDROCK_AWS_REGION` - Your AWS region (e.g., `us-east-1`, `us-west-2`)
- `BEDROCK_AWS_PROFILE` - Your AWS profile name from `~/.aws/credentials`

### Basic Usage

To use any of these models in your assistant, add them with the required inputs:

```yaml
models:
  - uses: bedrock/anthropic-claude-sonnet-4-20250514-v1-0
    with:
      BEDROCK_AWS_REGION: us-east-1
      BEDROCK_AWS_PROFILE: default

  - uses: bedrock/anthropic-claude-3-haiku-20240307-v1-0-200k
    with:
      BEDROCK_AWS_REGION: us-west-2
      BEDROCK_AWS_PROFILE: my-bedrock-profile
```

### Available Models

#### Latest Claude Models
- `bedrock/anthropic-claude-sonnet-4-20250514-v1-0` - Claude Sonnet 4 (latest)
- `bedrock/anthropic-claude-opus-4-20250514-v1-0` - Claude Opus 4
- `bedrock/anthropic-claude-opus-4-1-20250805-v1-0` - Claude Opus 4.1
- `bedrock/anthropic-claude-3-7-sonnet-20250219-v1-0` - Claude 3.7 Sonnet

#### Claude 3.5 Series
- `bedrock/anthropic-claude-3-5-sonnet-20241022-v2-0` - Claude 3.5 Sonnet v2
- `bedrock/anthropic-claude-3-5-sonnet-20240620-v1-0` - Claude 3.5 Sonnet v1
- `bedrock/anthropic-claude-3-5-haiku-20241022-v1-0` - Claude 3.5 Haiku

#### Claude 3 Series with Context Length Variants
Each base model has multiple context length options:

**Claude 3 Haiku:**
- `bedrock/anthropic-claude-3-haiku-20240307-v1-0` (default)
- `bedrock/anthropic-claude-3-haiku-20240307-v1-0-200k` (200k context)
- `bedrock/anthropic-claude-3-haiku-20240307-v1-0-48k` (48k context)

**Claude 3 Opus:**
- `bedrock/anthropic-claude-3-opus-20240229-v1-0` (default)
- `bedrock/anthropic-claude-3-opus-20240229-v1-0-200k` (200k context)
- `bedrock/anthropic-claude-3-opus-20240229-v1-0-28k` (28k context)
- `bedrock/anthropic-claude-3-opus-20240229-v1-0-12k` (12k context)

**Claude 3 Sonnet:**
- `bedrock/anthropic-claude-3-sonnet-20240229-v1-0` (default)
- `bedrock/anthropic-claude-3-sonnet-20240229-v1-0-200k` (200k context)
- `bedrock/anthropic-claude-3-sonnet-20240229-v1-0-28k` (28k context)

#### Legacy Models
- `bedrock/anthropic-claude-instant-v1` - Claude Instant
- `bedrock/anthropic-claude-instant-v1-2-100k` - Claude Instant (100k context)
- `bedrock/anthropic-claude-v2` - Claude v2
- Various Claude v2 context variants

### AWS Setup Requirements

1. **Install AWS CLI:** `aws configure` or use AWS SSO
2. **Set up credentials** in `~/.aws/credentials` or configure your preferred AWS authentication method
3. **Enable Bedrock models** in your AWS account region
4. **Verify access:** Run `aws bedrock list-foundation-models --region your-region` to confirm you can access the models

### Example Assistant Configuration

```yaml
name: "AWS Bedrock Assistant"
description: "Assistant using Claude models via AWS Bedrock"

models:
  # Main model with tool use
  - uses: bedrock/anthropic-claude-sonnet-4-20250514-v1-0
    with:
      BEDROCK_AWS_REGION: us-east-1
      BEDROCK_AWS_PROFILE: default

  # High-context model for large documents
  - uses: bedrock/anthropic-claude-3-opus-20240229-v1-0-200k
    with:
      BEDROCK_AWS_REGION: us-east-1
      BEDROCK_AWS_PROFILE: default

  # Fast model for quick tasks
  - uses: bedrock/anthropic-claude-3-haiku-20240307-v1-0
    with:
      BEDROCK_AWS_REGION: us-east-1
      BEDROCK_AWS_PROFILE: default
```

### Features

- **Tool Use Support:** All models include `tool_use` capability for function calling
- **Context Length Configuration:** Models with explicit context lengths include `defaultCompletionOptions.contextLength`
- **Multiple Regions:** Use different AWS regions by setting `BEDROCK_AWS_REGION`
- **Profile Support:** Use different AWS profiles with `BEDROCK_AWS_PROFILE`

### Learn More

- [Continue Blocks Documentation](https://docs.continue.dev/hub/blocks/use-a-block)
- [Continue Configuration Reference](https://docs.continue.dev/reference)
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)

For additional information, see the [Continue 1.0 Partnership Guide](https://continuedev.notion.site/Continue-1-0-Partnership-Guide-1811d55165f7802686fcd0b70464e778).
