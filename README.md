# 🧪 AI Safety Net [Experimental]

**Self-healing scripts for autonomous AI assistants**

When you give an AI assistant access to modify its own config... what happens when it breaks itself?

A dead assistant can't diagnose its own death. These scripts run *outside* the assistant to catch failures and attempt recovery.

## The Problem

Autonomous AI assistants can:
- Restart services
- Modify configs
- Break themselves

And when they're dead, they can't fix themselves.

## The Solution

External safety nets that survive the assistant's death:

```
┌─────────────────────────────────────────────┐
│  AI Assistant (can die)                     │
│  - Can modify config                        │
│  - Can restart gateway                      │
│  - Can break itself                         │
└─────────────────────────────────────────────┘
         │
         │ Before risky operation:
         │ spawns external safety net
         ▼
┌─────────────────────────────────────────────┐
│  Safety Net (survives assistant death)      │
│  - Waits N minutes                          │
│  - Checks if assistant is healthy           │
│  - If dead → attempts recovery              │
│  - If recovery fails → calls Claude API     │
│  - Always alerts human                      │
└─────────────────────────────────────────────┘
```

## Scripts

| Script | Purpose |
|--------|---------|
| `preflight.sh` | Run before risky ops. Backs up config, logs to changelog, spawns safety net |
| `safety-net.sh` | Detached guardian. Waits, checks health, recovers if needed |
| `watchdog.sh` | Background monitor via cron. Catches crashes between operations |

## Installation

```bash
git clone https://github.com/48Nauts-Operator/ai-safety-net.git
cd ai-safety-net
chmod +x scripts/*.sh

# Optional: Add watchdog to cron (every 5 min)
(crontab -l 2>/dev/null; echo "*/5 * * * * $PWD/scripts/watchdog.sh") | crontab -
```

## Usage

### Before risky operations:
```bash
./scripts/preflight.sh "Updating gateway config"
# Now do your risky thing
```

### The safety net automatically:
1. Backs up current config
2. Logs to CHANGELOG.md
3. Spawns detached watchdog (5 min default)
4. If assistant dies → attempts recovery
5. If recovery fails → calls Claude API for diagnosis
6. Always alerts human

## Configuration

Edit `config.sh`:
```bash
DELAY_MINUTES=5           # How long safety net waits
HEALTH_ENDPOINT="http://localhost:3000/health"
BACKUP_DIR="$HOME/clawd/backups/config"
ANTHROPIC_API_KEY="sk-..."  # For emergency diagnosis calls
```

## Headless Model Access

The recovery script can call any LLM API for diagnosis when your assistant is dead. Here are working examples for each provider:

### Claude (Anthropic)
```bash
curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Diagnose this..."}]
  }'
```

### GPT (OpenAI)
```bash
curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Diagnose this..."}]
  }'
```

### Gemini (Google)
```bash
curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$GOOGLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{"parts": [{"text": "Diagnose this..."}]}]
  }'
```

### LM Studio (Local)
```bash
curl -s http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-model",
    "messages": [{"role": "user", "content": "Diagnose this..."}]
  }'
```

### Ollama (Local)
```bash
curl -s http://localhost:11434/api/generate \
  -d '{
    "model": "llama2",
    "prompt": "Diagnose this...",
    "stream": false
  }'
```

### OpenCode (via ACP)
```bash
# Start session
SESSION=$(curl -s http://localhost:9777/sessions -X POST \
  -H "Content-Type: application/json" \
  -d '{"path": "/tmp/recovery"}' | jq -r '.id')

# Send prompt
curl -s "http://localhost:9777/sessions/$SESSION/message" -X POST \
  -H "Content-Type: application/json" \
  -d '{"content": "Diagnose this..."}'
```

The default script uses Claude. To switch providers, edit the `call_claude_for_help()` function in `safety-net.sh`.

## Built For

- [OpenClaw](https://github.com/openclaw/openclaw) (formerly Clawdbot)
- Any autonomous AI assistant setup

## Status

🧪 **Experimental** — We're actively testing these scripts. Feedback welcome.

## License

MIT

## Author

[@andrewolke](https://twitter.com/andrewolke) | [21nauts](https://21nauts.com)
