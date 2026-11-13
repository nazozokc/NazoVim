vim.opt.rtp:prepend("apps/nvim")
vim.g.mapleader = " "
vim.o.swapfile = false

local function equal(actual, expected, label)
	assert(
		vim.deep_equal(actual, expected),
		(label or "") .. ": " .. vim.inspect(actual) .. " != " .. vim.inspect(expected)
	)
end

local guard = require("nazovim.ai.lib.guard")

-- Sensitive paths never leave the editor, but templates and public keys do.
for _, path in ipairs({
	".env",
	"config/.env.local",
	"~/.ssh/id_ed25519",
	"server.pem",
	"credentials.json",
	"credentials.toml",
	".pypirc",
	".yarnrc.yml",
	"~/.kube/config",
	"~/.azure/accessTokens.json",
	"deploy.tfstate",
	"src/.env (target)",
}) do
	assert(guard.sensitive_path(path), path .. " should be sensitive")
end
equal(guard.sensitive_path(".env.example"), nil, ".env.example")
equal(guard.sensitive_path("id_ed25519.pub"), nil, "public key")
equal(guard.sensitive_path("notes.txt"), nil, "plain text")

-- Common token shapes and assignments are replaced before the prompt is built.
local text = table.concat({
	"GITHUB_TOKEN=ghp_abcdefghijklmnopqrstuvwxyz0123456789",
	"aws = AKIAIOSFODNN7EXAMPLE",
	'api_key = "super-secret-value"',
	"password: hunter2",
	"Authorization: Bearer abc.def.ghi",
	"url = https://user:pass@example.com/path",
	"-----BEGIN RSA PRIVATE KEY-----",
	"MIIEowIBAAKCAQEAsecret",
	"-----END RSA PRIVATE KEY-----",
}, "\n")
local redacted, count = guard.redact(text)
assert(not redacted:find("ghp_", 1, true), "GitHub token survived")
assert(not redacted:find("AKIA", 1, true), "AWS key survived")
assert(not redacted:find("super-secret-value", 1, true), "quoted assignment survived")
assert(not redacted:find("hunter2", 1, true), "unquoted assignment survived")
assert(not redacted:find("abc.def.ghi", 1, true), "bearer token survived")
assert(not redacted:find("pass@example", 1, true), "URL password survived")
assert(not redacted:find("MIIEow", 1, true), "private key survived")
assert(redacted:find("%[REDACTED%]"), "no marker was written")
assert(count >= 6, "redaction count: " .. tostring(count))

-- JSON keys and cookie headers are redacted too.
local quoted = guard.redact('{"password": "hunter3", "cookie": "a=b; c=d"}')
assert(not quoted:find("hunter3", 1, true), "quoted JSON password survived")
assert(not quoted:find("a=b", 1, true), "quoted cookie survived")

-- A symlink must not smuggle a sensitive file through an innocent name.
local link_dir = vim.fn.tempname()
vim.fn.mkdir(link_dir, "p")
local secret_path = link_dir .. "/.env"
local link_path = link_dir .. "/notes.txt"
vim.fn.writefile({ "TOKEN=secret" }, secret_path)
local uv = vim.uv or vim.loop
local linked = uv.fs_symlink(secret_path, link_path)
if linked then
	assert(guard.sensitive_path(link_path), "symlink to .env was accepted")
end
vim.fn.delete(link_dir, "rf")

assert(guard.sensitive_path("bad\npath.lua"), "control characters in a path were accepted")
equal(guard.input_path("a.lua"), "a.lua", "input path")
equal(guard.input_path("bad\npath"), nil, "input path control character")

-- A body containing fences cannot break out of its block.
local fenced = guard.context({ path = "a.md", filetype = "markdown", body = "```\ninner\n```" })
assert(fenced, "fenced context was rejected")
local fenced_prompt = guard.prompt("q", { fenced })
assert(fenced_prompt:find("````markdown", 1, true), "dynamic fence was not long enough")
assert(fenced_prompt:find("```\ninner", 1, true), "body was rewritten")

-- Redaction runs before truncation, so a cut private key is still gone.
local key_body = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAsecret\n"
key_body = key_body .. string.rep("A", 4096) .. "\n-----END RSA PRIVATE KEY-----"
local key_context = guard.context({ path = "a.txt", body = key_body }, 128)
assert(key_context, "key context was rejected")
assert(not key_context.body:find("MIIEow", 1, true), "truncated private key escaped redaction")

-- Contexts are denied, bounded, and redacted individually.
local safe, reason = guard.context({ path = ".env", body = "A=1" })
equal(safe, nil, "sensitive context")
assert(reason, "sensitive context has no reason")
safe, reason = guard.context({ path = "a.lua", body = "ok\0bad" })
equal(safe, nil, "binary context")
equal(reason, "binary content", "binary reason")
local filtered = guard.context({ path = "a.lua", filetype = "lua", body = 'token = "abc"' })
assert(filtered, "safe context was rejected")
equal(filtered.redactions, 1, "context redactions")
assert(not filtered.body:find("abc", 1, true), "context token survived")

-- The assembled prompt reports skips and marks reference material as data.
local prompt, report = guard.prompt("why?", {
	{ path = "a.lua", filetype = "lua", body = "password: x" },
	{ path = ".env", body = "A=1" },
})
assert(report.redactions >= 1, "prompt redactions")
equal(#report.skipped, 1, "prompt skips")
assert(prompt:find("untrusted data", 1, true), "prompt has no data warning")
assert(not prompt:find("password: x", 1, true), "prompt kept a secret")

-- Code is validated before it can be written into a buffer.
local code, code_reason = guard.code(nil)
equal(code, nil, "nil code")
assert(code_reason, "nil code has no reason")
equal(guard.code("print(1)"), "print(1)", "plain code")

-- Limits are clamped so a user setting cannot disable the guards.
vim.g.nazovim_ai_timeout = 1
equal(guard.timeout(), 10000, "timeout lower bound")
vim.g.nazovim_ai_timeout = nil

-- The ask module exposes the hardened providers and the new entry points.
local ask = require("nazovim.ai.ask")
ask.setup()
assert(vim.fn.exists(":NazoAI") == 2, ":NazoAI is missing")
for _, name in ipairs({
	"NazoAIDiff",
	"NazoAIQuickfix",
	"NazoAIExplain",
	"NazoAIFix",
	"NazoAIReview",
	"NazoAITest",
	"NazoAIDocs",
}) do
	assert(vim.fn.exists(":" .. name) == 2, name .. " is missing")
end
for _, key in ipairs({
	"<leader>ad",
	"<leader>aq",
	"<leader>aE",
	"<leader>aF",
	"<leader>aR",
	"<leader>aT",
	"<leader>aD",
}) do
	assert(vim.fn.maparg(key, "n") ~= "", key .. " is missing")
end
local command = ask.command("codex", "hello")
assert(vim.tbl_contains(command, "--sandbox"), "codex has no sandbox flag")
assert(vim.tbl_contains(command, "read-only"), "codex is not read-only")
assert(vim.tbl_contains(command, "--ephemeral"), "codex is not ephemeral")
assert(vim.tbl_contains(command, "--ignore-rules"), "codex rules are not ignored")
assert(vim.tbl_contains(command, "features.shell_tool=false"), "codex shell tool is enabled")
assert(vim.tbl_contains(command, "-"), "codex has no stdin marker")
assert(not vim.tbl_contains(command, "hello"), "codex prompt leaked into argv")
command = ask.command("claude", "hello")
assert(vim.tbl_contains(command, "--tools"), "claude has no tools flag")
assert(vim.tbl_contains(command, ""), "claude tools are not disabled")
assert(vim.tbl_contains(command, "--restricted"), "claude is not restricted")
assert(vim.tbl_contains(command, "--safe-mode"), "claude is not in safe mode")
assert(vim.tbl_contains(command, "--strict-mcp-config"), "claude MCP config is not isolated")
assert(not vim.tbl_contains(command, "hello"), "claude prompt leaked into argv")
command = ask.command("opencode", "hello")
assert(vim.tbl_contains(command, "--pure"), "opencode does not skip plugins")
equal(ask.code_blocks("a\n```lua\nprint(1)\n```\nb"), { "print(1)" }, "code blocks")
assert(ask.build_prompt("q", { { path = "a.lua", filetype = "lua", body = "x" } }):find("untrusted data", 1, true))

print("ai: guard, prompts and commands passed")
