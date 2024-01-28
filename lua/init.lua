---@class Args
---@field neovide_channel_id integer
---@field register_clipboard boolean
---@field register_right_click boolean
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
        cache_enabled = 0
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

vim.api.nvim_exec([[
function! WatchGlobal(variable, callback)
    call dictwatcheradd(g:, a:variable, a:callback)
endfunction
]], false)

for _,global_variable_setting in ipairs(args.global_variable_settings) do
    local callback = function()
        rpcnotify("setting_changed", global_variable_setting, vim.g["neovide_" .. global_variable_setting])
    end
    vim.fn.WatchGlobal("neovide_" .. global_variable_setting, callback)
end

for _,option_setting in ipairs(args.option_settings) do
    vim.api.nvim_create_autocmd({ "OptionSet" }, {
        pattern = option_setting,
        once = false,
        nested = true,
        callback = function()
            rpcnotify("option_changed", option_setting, vim.o[option_setting])
        end
    })
end

-- Create auto command for retrieving exit code from neovim on quit.
vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    pattern = "*",
    once = true,
    nested = true,
    callback = function()
        rpcnotify("neovide.quit", vim.v.exiting)
    end
})

local function unlink_highlight(name)
    local highlight = vim.api.nvim_get_hl(0, {name=name, link=false})
    vim.api.nvim_set_hl(0, name, highlight)
end

local lazypath = vim.fn.stdpath("data") .."/lazy/lazy.nvim"
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

	-- File browsing tree
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
			"3rd/image.nvim"
		}
	},

	-- highlighting and indexing functions
	"nvim-treesitter/nvim-treesitter",

	-- theme
	{
		"catppuccin/nvim",
		as = "catppuccin",
		priority = 1000
	},
	
	-- lsp
	"williamboman/mason.nvim",
	"williamboman/mason-lspconfig.nvim",
	"neovim/nvim-lspconfig",
	"simrat39/rust-tools.nvim",

	-- autocomplete engine
	"hrsh7th/nvim-cmp",
	"hrsh7th/cmp-nvim-lsp",
	"hrsh7th/cmp-nvim-lsp-signature-help",
	"hrsh7th/cmp-vsnip",
	"hrsh7th/cmp-path",
	"hrsh7th/cmp-buffer",

	-- vscode snipped feature
	"hrsh7th/vim-vsnip",

	-- floating terminal
	"voldikss/vim-floaterm",

	-- speed up startup???
	"lewis6991/impatient.nvim",

	-- tabs
	{
		"romgrk/barbar.nvim",
		dependencies = {
			"lewis6991/gitsigns.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		init = function() vim.g.barbar_auto_setup = true end,
	},

	-- status line prettify
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" }
	},

	-- dashboard
	{
		"nvimdev/dashboard-nvim",
		event = "VimEnter",
		config = function()
			require("dashboard").setup {
				theme = "hyper",
				config = {
					week_header = {
						enable = true,
					},
					shortcut = {
						{ 
							desc = "󰊳  Update", 
							group = "@property", 
							action = "Lazy update", 
							key = "u" 
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
			}
		end,
		dependencies = { {"nvim-tree/nvim-web-devicons" } }
	},
	"pocco81/auto-save.nvim",
})

vim.keymap.set("n", "<leader>ft", ":FloaterNew --name=myfloat --height=0.8 --autoclose=2 fish <CR> ")
vim.keymap.set("n", "t", ":FloatermToggle myfloat<CR>")
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>:q<CR>")

-- Change buffer mappings
vim.keymap.set("n", "<A-,>", "<Cmd>BufferPrevious<CR>")
vim.keymap.set("n", "<A-.>", "<Cmd>BufferNext<CR>")
vim.keymap.set("n", "<A-c>", "<Cmd>BufferClose<CR>")
vim.keymap.set("n", "<A-z>", "<Cmd>BufferRestore<CR>")

require("mason").setup({
	ui = {
		icons = {
			package_installed = "",
			package_pending = "",
			package_inuninstalled = "",
		},
	}
})
require("mason-lspconfig").setup({
	automatic_installation = true
})

local lspconfig = require("lspconfig")
lspconfig.rust_analyzer.setup {}
lspconfig.gopls.setup {}
lspconfig.biome.setup {}
lspconfig.golangci_lint_ls.setup {}
lspconfig.grammarly.setup {}
lspconfig.java_language_server.setup {}
lspconfig.jsonls.setup {}
lspconfig.quick_lint_js.setup {}

require("nvim-treesitter.configs").setup {
	ensure_installed = {  
		"lua", "rust", "java", "go", "cpp",
	},
	auto_install = true,
	highlight = {
		enable = true,
		additional_vim_regex_highlighting = false,
	},
	ident = { 
		enable = true 
	},
	rainbow = {
		enable = true,
		extended_mode = true,
		max_file_lines = nil,
	}
}

vim.opt.completeopt = { "menuone", "noselect", "noinsert" }
vim.opt.shortmess = vim.opt.shortmess + { c = true }
vim.api.nvim_set_option("updatetime", 750)

vim.g.floaterm_title = "≽^•⩊•^≼"
vim.g.floaterm_wintype = "Float"
vim.g.floaterm_position = "bottom"
vim.g.floaterm_width = 0.99999
vim.g.floaterm_height = 0.25

require("lualine").setup({
	options = { theme = "ayu_mirage" }
})

local cmp = require("cmp")
cmp.setup({
	snippet = {
		expand = function(args)
			vim.fn["vsnip#anonymous"](args.body)
		end,
	},
	mapping = {
		["<C-p>"] = cmp.mapping.select_prev_item(),
		["<C-n>"] = cmp.mapping.select_next_item(),
		["<S-Tab>"] = cmp.mapping.select_prev_item(),
		["<Tab>"] = cmp.mapping.select_next_item(),
		["<C-S-f>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.close(),
		["<CR>"] = cmp.mapping.confirm({
			behavior = cmp.ConfirmBehavior.Insert,
			select = true,
		})
	},
	sources = {
		{ name = "path" },
		{ name = "nvim_lsp" },
		{ name = "nvim_lsp_signature_help"},
		{ name = "nvim_lua", keyword_length = 2 },
		{ name = "buffer", keyword_length = 2 },
		{ name = "vsnip", keyword_length = 2 },
		{ name = "calc" },
	},
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
	formatting = {
		fields = { "menu", "abbr", "kind"},
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

local rt = require("rust-tools")
rt.setup({
	server = {
		on_attach = function(_, bufnr)
			vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, {buffer = bufnr })
			vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, {buffer = bufnr })
		end,
	},
})


local sign = function(opts)
	vim.fn.sign_define(opts.name, {
		texthl = opts.name,
		text = opts.text,
		numhl = ""
	})
end
sign({name = "DiagnosticsSignError", text = ""})
sign({name = "DiagnosticSignWarn", text = ""})
sign({name = "DiagnosticSignHint", text = ""})
sign({name = "DiagnosticsSignInfo", text = ""})
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
]]
)

require("catppuccin").setup({
	integrations = {
		neotree = true
	}
})

local alpha = function()
	return string.format("%x", math.floor(255 * vim.g.transparency or 1))
end

vim.cmd.colorscheme "catppuccin"
vim.g.neovide_transparency = 0.9
vim.g.transparency = 0.8
vim.g.neovide_background_color = "#0f1117" .. alpha()
vim.g.neovide_theme = "catppuccin"
vim.g.neovide_remember_window_size = true
vim.g.neovide_cursor_vfx_mode = "wireframe"

vim.wo.number = true

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
end
})

