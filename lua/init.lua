---@class Args
---@field neovide_channel_id integer
---@field register_clipboard boolean:
---@field enable_focus_command boolean
---@field global_variable_settings string[]
---@field option_settings string[]

---@type Args
local args = ...

vim.g.neovide_channel_id = args.neovide_channel_id

-- Set some basic rendering options.
vim.o.lazyredraw = false
vim.o.termguicolors = true

local function rpcnotify(method, ...)
	vim.rpcnotify(vim.g.neovide_channel_id, method, ...)
end

local function rpcrequest(method, ...)
	return vim.rpcrequest(vim.g.neovide_channel_id, method, ...)
end

local function set_clipboard(register)
	return function(lines, regtype)
		rpcrequest("neovide.set_clipboard", lines)
	end
end

local function get_clipboard(register)
	return function()
		return rpcrequest("neovide.get_clipboard", register)
	end
end

if args.register_clipboard and not vim.g.neovide_no_custom_clipboard then
	vim.g.clipboard = {
		name = "neovide",
		copy = {
			["+"] = set_clipboard("+"),
			["*"] = set_clipboard("*"),
		},
		paste = {
			["+"] = get_clipboard("+"),
			["*"] = get_clipboard("*"),
		},
		cache_enabled = 0,
	}
end

if args.register_right_click then
	vim.api.nvim_create_user_command("NeovideRegisterRightClick", function()
		rpcnotify("neovide.register_right_click")
	end, {})
	vim.api.nvim_create_user_command("NeovideUnregisterRightClick", function()
		rpcnotify("neovide.unregister_right_click")
	end, {})
end

vim.api.nvim_create_user_command("NeovideFocus", function()
	rpcnotify("neovide.focus_window")
end, {})

vim.api.nvim_exec(
	[[
function! WatchGlobal(variable, callback)
call dictwatcheradd(g:, a:variable, a:callback)
endfunction
]],
	false
)

for _, global_variable_setting in ipairs(args.global_variable_settings) do
	local callback = function()
		rpcnotify("setting_changed", global_variable_setting, vim.g["neovide_" .. global_variable_setting])
	end
	vim.fn.WatchGlobal("neovide_" .. global_variable_setting, callback)
end

for _, option_setting in ipairs(args.option_settings) do
	vim.api.nvim_create_autocmd({ "OptionSet" }, {
		pattern = option_setting,
		once = false,
		nested = true,
		callback = function()
			rpcnotify("option_changed", option_setting, vim.o[option_setting])
		end,
	})
end

-- Create auto command for retrieving exit code from neovim on quit.
vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
	pattern = "*",
	once = true,
	nested = true,
	callback = function()
		rpcnotify("neovide.quit", vim.v.exiting)
	end,
})

local function unlink_highlight(name)
	local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
	vim.api.nvim_set_hl(0, name, highlight)
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "

require("lazy").setup({

	-- Misc
	"nvim-treesitter/nvim-treesitter",
	"lewis6991/impatient.nvim",
	"pocco81/auto-save.nvim",

	-- theme
	{
		"catppuccin/nvim",
		as = "catppuccin",
		priority = 1000,
	},

	-- LSP
	{
		"neovim/nvim-lspconfig",
		autoformat = true,
	},
	{
		"williamboman/mason.nvim",
		opts = {
			ui = {
				icons = {
					package_installed = "",
					package_pending = "",
					package_inuninstalled = "",
				},
			},
		},
	},
	-- More LSP
	"saadparwaiz1/cmp_luasnip",
	"L3MON4D3/LuaSnip",
	"williamboman/mason-lspconfig.nvim",
	"hrsh7th/nvim-cmp",
	"hrsh7th/cmp-nvim-lsp",
	"hrsh7th/cmp-nvim-lsp-signature-help",
	"hrsh7th/cmp-vsnip",
	"hrsh7th/cmp-path",
	"hrsh7th/cmp-buffer",

	-- LSP / autocomplete tools
	"simrat39/rust-tools.nvim",
	"pmizio/typescript-tools.nvim",
	"folke/neodev.nvim",
	"joeveiga/ng.nvim",
	{
		"mfussenegger/nvim-jdtls",
		dependencies = { "folke/which-key.nvim" },
	},
	{
		"saecki/crates.nvim",
		event = { "BufRead Cargo.toml" },
		config = function()
			require("crates").setup()
		end,
	},
	"stevearc/conform.nvim",

	-- vscode snipped feature
	"hrsh7th/vim-vsnip",

	----------------------------------------------------------
	-- Utilities!
	-- floating terminal
	"voldikss/vim-floaterm",

	-- File browsing tree
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
	},
	"nvim-lua/plenary.nvim",
	"MunifTanjim/nui.nvim",
	"3rd/image.nvim",

	-- tabs
	{
		"romgrk/barbar.nvim",
		dependencies = {
			"lewis6991/gitsigns.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		init = function()
			vim.g.barbar_auto_setup = true
		end,
	},

	-- status line
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			options = { theme = "catppuccin" },
		},
	},

	-- dashboard
	{
		"nvimdev/dashboard-nvim",
		event = "VimEnter",
		dependencies = { { "nvim-tree/nvim-web-devicons" } },
		config = function()
			require("dashboard").setup({
				config = {
					week_header = {
						enable = true,
					},
					shortcut = {
						{
							desc = "󰊳  Update",
							group = "@property",
							action = "Lazy update",
							key = "u",
						},
						{
							icon = " ",
							icon_hl = "@variable",
							desc = "Files",
							group = "Label",
							action = "Telescope find_files",
							key = "f",
						},
						{
							desc = " Apps",
							group = "DiagnosticHint",
							action = "Telescope app",
							key = "a",
						},
						{
							desc = " dotfiles",
							group = "Number",
							action = "Telescope dotfiles",
							key = "d",
						},
					},
				},
			})
		end,
	},
	----------------------------------------------------------
})

-- Change buffer mappings
vim.keymap.set("n", "<A-,>", "<Cmd>BufferPrevious<CR>")
vim.keymap.set("n", "<A-.>", "<Cmd>BufferNext<CR>")
vim.keymap.set("n", "<A-c>", "<Cmd>BufferClose<CR>")
vim.keymap.set("n", "<A-z>", "<Cmd>BufferRestore<CR>")

-- file tree toggle
vim.keymap.set("n", "<F12>", "<Cmd>NvimTreeToggle<CR>")

-- i don't know
vim.opt.completeopt = { "menuone", "noselect", "noinsert" }
vim.opt.shortmess = vim.opt.shortmess + { c = true }
vim.api.nvim_set_option("updatetime", 750)

-- terminal
vim.keymap.set("n", "<leader>ft", ":FloaterNew --name=myfloat --height=0.8 --autoclose=2 fish <CR> ")
vim.keymap.set("n", "t", ":FloatermToggle myfloat<CR>")
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>:q<CR>")
vim.g.floaterm_title = "≽^•⩊•^≼"
vim.g.floaterm_wintype = "Float"
vim.g.floaterm_position = "bottom"
vim.g.floaterm_width = 0.99999
vim.g.floaterm_height = 0.25

vim.cmd.colorscheme("catppuccin")
vim.g.neovide_transparency = 0.95
vim.g.transparency = 0.95
vim.g.neovide_background_color = "#0f1117" .. string.format("%x", math.floor(255 * vim.g.transparency or 1))
vim.g.neovide_theme = "catppuccin"
vim.g.neovide_remember_window_size = true
vim.g.neovide_cursor_vfx_mode = "wireframe"
vim.wo.number = true

require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"lua",
		"rust",
		"java",
		"go",
		"cpp",
		"angular",
		"c",
		"cpp",
		"css",
		"arduino",
		"html",
		"http",
		"javascript",
		"typescript",
		"json",
		"python",
		"scss",
		"sql",
		"tsx",
		"xml",
		"yaml",
		"gitignore",
		"gitcommit",
		"dockerfile",
		"properties",
	},
	auto_install = true,
	highlight = {
		enable = true,
		additional_vim_regex_highlighting = false,
	},
	ident = {
		enable = true,
	},
	rainbow = {
		enable = true,
		extended_mode = true,
		max_file_lines = nil,
	},
})

------------------------------------------
-- important: this comes before lspconfig!
local rt = require("rust-tools")
rt.setup({
	server = {
		on_attach = function(_, bufnr)
			vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
			vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
		end,
	},
})
require("typescript-tools").setup({})
require("ng")
require("neodev").setup({})
-- TODO: this requires extensive setup...
require("jdtls")
require("crates").setup({})
------------------------------------------
require("mason").setup({})
local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()
lspconfig.angularls.setup({ capabilities = capabilities })
lspconfig.arduino_language_server.setup({ capabilities = capabilities })
lspconfig.biome.setup({ capabilities = capabilities })
lspconfig.clangd.setup({ capabilities = capabilities })
lspconfig.cmake.setup({ capabilities = capabilities })
lspconfig.cssls.setup({ capabilities = capabilities })
lspconfig.dockerls.setup({ capabilities = capabilities })
lspconfig.dotls.setup({ capabilities = capabilities })
lspconfig.golangci_lint_ls.setup({ capabilities = capabilities })
lspconfig.gopls.setup({ capabilities = capabilities })
lspconfig.grammarly.setup({ capabilities = capabilities })
lspconfig.graphql.setup({ capabilities = capabilities })
lspconfig.html.setup({ capabilities = capabilities })
lspconfig.java_language_server.setup({ capabilities = capabilities })
lspconfig.jdtls.setup({ capabilities = capabilities })
lspconfig.jsonls.setup({ capabilities = capabilities })
lspconfig.lua_ls.setup({ capabilities = capabilities })
lspconfig.pyright.setup({ capabilities = capabilities })
lspconfig.rust_analyzer.setup({ capabilities = capabilities })
lspconfig.sqlls.setup({ capabilities = capabilities })
lspconfig.tsserver.setup({ capabilities = capabilities })
lspconfig.vimls.setup({ capabilities = capabilities })
require("mason-lspconfig").setup({
	automatic_installation = true,
})

local luasnip = require("luasnip")
local cmp = require("cmp")
cmp.setup({
	snippet = {
		expand = function(arg)
			luasnip.lsp_expand(arg.body)
		end,
	},
	mapping = cmp.mapping.preset.insert({
		["<C-u>"] = cmp.mapping.scroll_docs(-4), --Up
		["<C-d>"] = cmp.mapping.scroll_docs(4), --Down
		["<C-Space>"] = cmp.mapping.complete(),
		["<CR>"] = cmp.mapping.confirm({
			behavior = cmp.ConfirmBehavior.Insert,
			select = true,
		}),
		["<Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			elseif luasnip.expand_or_jumpable() then
				luasnip.expand_or_jump()
			else
				fallback()
			end
		end, { "i", "s" }),
		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			elseif luasnip.jumpable(-1) then
				luasnip.jump(-1)
			else
				fallback()
			end
		end, { "i", "s" }),
	}),
	sources = {
		{ name = "path" },
		{ name = "nvim_lsp" },
		{ name = "nvim_lsp_signature_help" },
		{ name = "nvim_lua", keyword_length = 2 },
		{ name = "buffer", keyword_length = 2 },
		{ name = "vsnip", keyword_length = 2 },
		{ name = "calc" },
		{ name = "luasnip" },
	},
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
	formatting = {
		fields = { "menu", "abbr", "kind" },
		format = function(entry, item)
			local menu_icon = {
				nvim_lsp = "λ",
				vsnip = "⋗",
				buffer = "Ω",
				path = "🖫",
			}
			item.menu = menu_icon[entry.source.name]
			return item
		end,
	},
})

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

		local opts = { buffer = ev.buf }
		vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
		vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
		vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
		vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, opts)
		vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, opts)
		vim.keymap.set("n", "<space>wl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, opts)
		vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, opts)
		vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)
		vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, opts)
		vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
		vim.keymap.set("n", "<space>f", function()
			vim.lsp.buf.format({ async = true })
		end, opts)
	end,
})

-----------------------------------------------------------------------------------------------
--- Code formatters! ---
require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		go = { "gofumpt", "goimports", "golines", "gci" },
		javascript = { { "biome", "prettierd", "prettier" } },
		typescript = { { "biome", "prettierd", "prettier" } },
		html = { { "prettierd", "prettier" } },
		css = { { "prettierd", "prettier" }, "stylelint" },
		python = { "black" },
		c = { "clang_format" },
		cpp = { "clang_format" },
		cmake = { "gersemi" },
		java = { "google-java-format" },
		yaml = { "yamlfix" },
		rust = { "rustfmt" },
		xml = { "xmlformat" },
		sql = { "sqlfmt" },
	},
	formatters = {
		biome = {
			command = "biome",
		},
		-- python
		black = {
			command = "black",
		},
		clang_format = {
			command = "clang",
		},
		-- go package import order
		gci = {
			command = "gci",
		},
		gersemi = {
			command = "gersemi",
		},
		-- stricter gofmt
		gofumpt = {
			command = "gofumpt",
		},
		goimports = {
			command = "goimports",
		},
		golines = {
			command = "golines",
		},
		google_java_format = {
			command = "java",
		},
		prettier = {
			command = "prettier",
		},
		prettierd = {
			command = "prettierd",
		},
		rustfmt = {
			command = "rustfmt",
		},
		sqlfmt = {
			command = "sqlfmt",
		},
		stylelint = {
			command = "stylelint",
		},
		stylua = {
			command = "stylua",
		},
		xmlformat = {
			command = "xmlformat",
		},
		yamlfix = {
			command = "yamlfmt",
		},
	},
	format_on_save = {
		lsp_fallback = true,
		timeout_ms = 500,
	},
	format_after_save = {
		lsp_fallback = true,
	},
	notify_on_error = true,
})
-----------------------------------------------------------------------------------------------

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.termguicolors = true
require("nvim-tree").setup({
	view = {
		width = 40,
	},
})

local sign = function(opts)
	vim.fn.sign_define(opts.name, {
		texthl = opts.name,
		text = opts.text,
		numhl = "",
	})
end
sign({ name = "DiagnosticsSignError", text = "" })
sign({ name = "DiagnosticSignWarn", text = "" })
sign({ name = "DiagnosticSignHint", text = "" })
sign({ name = "DiagnosticsSignInfo", text = "" })

vim.diagnostic.config({
	virtual_text = false,
	signs = true,
	update_in_insert = true,
	underline = true,
	severity_sort = false,
	float = {
		border = "rounded",
		source = "always",
		header = "",
		prefix = "",
	},
})

vim.cmd([[
set signcolumn=yes
autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
]])

require("catppuccin").setup({
	flavor = "mocha",
	integrations = {
		cmp = true,
		dashboard = true,
		nvimtree = true,
		mason = true,
	},
})

-- Neovim only reports the final highlight group in the ext_hlstate information
-- So we need to unlink all the groups when the color scheme is changed
-- This is quite hacky, so let the user disable it.
vim.api.nvim_create_autocmd({ "ColorScheme" }, {
	pattern = "*",
	nested = false,
	callback = function()
		if vim.g.neovide_unlink_border_highlights then
			unlink_highlight("FloatTitle")
			unlink_highlight("FloatFooter")
			unlink_highlight("FloatBorder")
			unlink_highlight("WinBar")
			unlink_highlight("WinBarNC")
		end
	end,
})
