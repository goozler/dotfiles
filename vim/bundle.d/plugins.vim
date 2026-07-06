call plug#begin('~/.vim/plugged')
" Edit
Plug 'AndrewRadev/splitjoin.vim'
Plug 'DataWraith/auto_mkdir'
Plug 'Raimondi/delimitMate'
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'deoplete-plugins/deoplete-lsp'
Plug 'catgoose/nvim-colorizer.lua'
" Plug 'bronson/vim-trailing-whitespace', { 'branch': 'nusendra:fix/TerminalOpen-event-not-found-in-nvim' }
" Plug 'nusendra/vim-trailing-whitespace', { 'branch': 'fix/TerminalOpen-event-not-found-in-nvim' }
Plug 'nusendra/vim-trailing-whitespace'
" Plug 'cakebaker/scss-syntax.vim', { 'for': ['sass', 'scss'] }
" Plug 'dkprice/vim-easygrep'
Plug 'easymotion/vim-easymotion'
Plug 'gorkunov/smartpairs.vim'
Plug 'vim-test/vim-test'
Plug 'jeetsukumaran/vim-buffergator'
Plug 'jeetsukumaran/vim-indentwise'
Plug 'jpalardy/vim-slime' " REPL
" Plug 'junegunn/fzf', { 'do': { -> fzf#install() }, 'tag': '0.41.1' }
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-easy-align'
Plug 'kshenoy/vim-signature'
" Plug 'ludovicchabant/vim-gutentags', { 'branch': 'vim7' }
Plug 'mattn/emmet-vim'
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
Plug 'moll/vim-node'
" Plug 'olimorris/codecompanion.nvim'
Plug 'nvim-treesitter/nvim-treesitter', {'branch': 'main', 'do': ':TSUpdate'}
Plug 'nvim-treesitter/nvim-treesitter-context'
Plug 'sbdchd/neoformat'
Plug 'editorconfig/editorconfig-vim'
Plug 'szw/vim-maximizer'
Plug 'thinca/vim-localrc'
" Plug 'tpope/vim-bundler'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-cucumber'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-obsession'
" Plug 'tpope/vim-rails'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-abolish'
Plug 'tpope/vim-tbone'

" Snippets
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'

" Lint
Plug 'neomake/neomake'
Plug 'jaawerth/nrun.vim'

" Tmux
Plug 'benmills/vimux'
Plug 'jgdavey/tslime.vim'
Plug 'tmux-plugins/vim-tmux-focus-events'

" UI
Plug 'lifepillar/vim-solarized8'
Plug 'scrooloose/nerdtree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }
Plug 'wesQ3/vim-windowswap'
Plug 'Yggdroot/indentLine'

" Documentation
" Plug 'danchoi/ri.vim'

" Git
Plug 'tpope/vim-fugitive' ", { 'tag': 'v3.1' }
Plug 'shumphrey/fugitive-gitlab.vim'
Plug 'mhinz/vim-signify'
Plug 'nvim-lua/plenary.nvim'              " required by diffview
Plug 'sindrets/diffview.nvim'             " PR-style file list + side-by-side diff browser

" Syntax
" Plug 'fatih/vim-go' ", { 'do': ':GoUpdateBinaries', 'for': 'go' }
Plug 'sheerun/vim-polyglot'
" Plug 'kchmck/vim-coffee-script', { 'for': ['coffee', 'eco'] } | Plug 'AndrewRadev/vim-eco', { 'for': 'eco' }
" Plug 'jparise/vim-graphql'

Plug 'neovim/nvim-lspconfig'

" Avante Deps
" Plug 'stevearc/dressing.nvim'
" Plug 'nvim-lua/plenary.nvim'
" Plug 'MunifTanjim/nui.nvim'
" Plug 'MeanderingProgrammer/render-markdown.nvim'

" Optional deps
" Plug 'hrsh7th/nvim-cmp'
" Plug 'nvim-tree/nvim-web-devicons' "or Plug 'echasnovski/mini.icons'
" Plug 'HakonHarnes/img-clip.nvim'
" Plug 'zbirenbaum/copilot.lua'

" Yay, pass source=true if you want to build from source
" Plug 'yetone/avante.nvim', { 'branch': 'main', 'do': 'make' }
call plug#end()
