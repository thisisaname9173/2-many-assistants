# 2 Many Assistants

### Your Garry's Mod server just got a little more conversational.

[![Garry's Mod](https://img.shields.io/badge/Garry's%20Mod-Workshop-4b8bbe?logo=steam&logoColor=white)](https://steamcommunity.com/sharedfiles/filedetails/?id=3752580694)
[![Security](https://img.shields.io/badge/AI%20Lua%20execution-disabled-2ea44f)](#safety--privacy)

Ask for a prop, a weapon, an NPC, a vehicle, or just a quick answer. The assistant turns requests into a small set of server-checked in-game actions—no Lua execution, no AI-issued console commands, and no “the model said so” admin powers.

> **Security first:** AI-generated Lua execution has been removed. The assistant only accepts supported actions, and every spawn is checked by the server.

---

## What it does

- 💬 Ask questions with `!ai <message>`.
- 🪑 Request registered props and spawn-menu content.
- 🤖 Ask for eligible NPCs, vehicles, entities, or weapons.
- 🪟 Get responses in chat or a small pop-up.
- 🎭 Set an optional server-wide persona.
- 🔌 Choose from Groq, OpenAI, OpenRouter, Anthropic, Gemini, Hugging Face, Cerebras, DeepSeek, and xAI.
- 🛡️ Apply server-side blacklist, permission, and spawn-limit checks.

The assistant needs an API key for a supported provider. API usage may incur charges from that provider.

## Install

1. Subscribe to the [Steam Workshop item](https://steamcommunity.com/sharedfiles/filedetails/?id=3752580694), or clone [this repository](https://github.com/thisisaname9173/2-many-assistants) into your Garry's Mod `garrysmod/addons` folder.

   ```powershell
   git clone https://github.com/thisisaname9173/2-many-assistants.git "C:\path\to\garrysmod\addons\2-many-assistants"
   ```

   The GitHub repository is private; Workshop is the easiest option for regular users.
2. Set your provider API key in the **server console**:

   ```text
   ai_set_api_key groq YOUR_API_KEY
   ```

   Replace `groq` with your provider name if needed. Keep API keys private; never paste them into chat or publish them in a config file or screenshot.

3. (Optional) Change provider or model:

   ```text
   ai_set_provider groq
   ai_set_model llama-3.3-70b-versatile
   ```

4. In game, try:

   ```text
   !ai spawn me a chair
   ```

Admins can also open the configuration menu with `ai_config` or `ai_config_menu`. The menu can save a new key without showing the currently saved key.

## Commands

| Command | Who can use it | What it does |
| --- | --- | --- |
| `!ai <request>` | Players | Send a request to the assistant |
| `ai <request>` | Server console | Send a request from the server console |
| `ai_config` / `ai_config_menu` | Players | Open the configuration menu (only admins can save changes) |
| `ai_set_api_key <provider> <key>` | Admin / server console | Set a provider API key |
| `ai_set_provider <provider>` | Admin / server console | Choose the API provider |
| `ai_set_model <model>` | Admin / server console | Choose the model |
| `ai_persona <text>` | Admin / server console | Set a custom assistant persona |
| `ai_persona_clear` | Admin / server console | Clear the custom persona |
| `ai_chat_enabled` / `ai_chat_disabled` | Admin / server console | Opt in or out of sending ordinary public chat to the AI |
| `ai_blacklist <model\|weapon\|all> <add\|remove\|list\|reset\|clear> [pattern]` | Admin / server console | Manage spawn/equip blacklist patterns |
| `ai_spawn_catalog_dump` | Admin / server console | Inspect registered spawn-menu content |
| `ai_chatlog_dump` / `ai_chatlog_clear` | Admin / server console | View or clear the in-memory public chat log |
| `ai_errorlog_dump` / `ai_errorlog_clear` | Admin / server console | View or clear the in-memory error log |

Supported provider names: `groq`, `openai`, `openrouter`, `anthropic`, `gemini`, `huggingface`, `cerebras`, `deepseek`, `xai`.

## Safety & privacy

- **No AI-generated Lua execution.** The old `run_lua` action and its execution sandbox are gone. `ai_lua_exec_enable` remains only as a compatibility command and cannot enable execution.
- **No AI-issued console commands.** The model cannot run server console commands.
- **Server-side checks.** Spawn-menu registration, admin-only entries, model validity, blacklists, and spawn locations are checked on the server.
- **Abuse limits.** Each player is limited to 4 AI spawns per minute and 8 live AI-spawned entities. Each AI response can trigger at most 3 actions.
- **Admin checks use actual Garry's Mod admin status.** A custom group name alone does not grant access.
- **Private chat stays private from this addon.** Team-chat messages are not logged or sent to the AI. Public chat is only sent when an admin explicitly enables chat mode.
- **Provider data handling:** requests and their conversation context are sent to the selected AI provider. Review that provider's privacy and retention policies before use.

## Configuration notes

The default blacklist blocks common explosive-themed prop models and weapons. Server owners can review or adjust patterns with `ai_blacklist`. Clearing a blacklist removes that list's protection, so do so only if you understand the content available on your server.

Some relevant server settings:

| ConVar | Default | Purpose |
| --- | --- | --- |
| `ai_groq_enabled` | `1` | Enable or disable the assistant |
| `ai_groq_chat_enabled` | `0` | Send ordinary public chat to the AI |
| `ai_cooldown` | `2` | Per-player request cooldown (minimum 2 seconds) |
| `ai_request_interval` | `1.5` | Global outgoing-request spacing (minimum 1.5 seconds) |
| `ai_model_blacklist` | Built-in patterns | Blocked prop model substrings |
| `ai_weapon_blacklist` | Built-in patterns | Blocked weapon classname substrings |

## Troubleshooting

- **“Set ai_api_key…”** — Set a key for the selected provider in the server console.
- **No response?** — Check that the assistant is enabled, the key is valid, and the server can reach the provider.
- **An item is refused?** — It may not be registered in the server's spawn menu, may be admin-only, or may match an active blacklist.
- **Need help?** — Check the server console and the admin-only `ai_errorlog_dump` output.

---

Made for Garry's Mod servers that want an AI helper without handing the AI the keys to the server.
