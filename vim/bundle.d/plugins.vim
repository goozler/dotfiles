call plug#begin('~/.vim/plugged')
" Edit
Plug 'AndrewRadev/splitjoin.vim'
Plug 'DataWraith/auto_mkdir'
Plug 'Raimondi/delimitMate'
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'bronson/vim-trailing-whitespace'
Plug 'dkprice/vim-easygrep'
Plug 'easymotion/vim-easymotion'
Plug 'gorkunov/smartpairs.vim'
Plug 'janko-m/vim-test'
Plug 'jeetsukumaran/vim-buffergator'
Plug 'jpalardy/vim-slime' " REPL
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-easy-align'
Plug 'kshenoy/vim-signature'
Plug 'ludovicchabant/vim-gutentags'
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
Plug 'moll/vim-node'
Plug 'sbdchd/neoformat'
Plug 'sgur/vim-editorconfig'
Plug 'szw/vim-maximizer'
Plug 'thinca/vim-localrc'
Plug 'tpope/vim-bundler'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-cucumber'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-obsession'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'

" Snippets
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'

" Lint
Plug 'neomake/neomake'
Plug 'benjie/neomake-local-eslint.vim'

" Tmux
Plug 'benmills/vimux'
Plug 'tmux-plugins/vim-tmux-focus-events'

" UI
Plug 'lifepillar/vim-solarized8'
Plug 'scrooloose/nerdtree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }
Plug 'vim-airline/vim-airline' | Plug 'vim-airline/vim-airline-themes'
Plug 'wesQ3/vim-windowswap'
Plug 'Yggdroot/indentLine'

" Documentation
Plug 'danchoi/ri.vim'

" Git
Plug 'tpope/vim-fugitive'
Plug 'mhinz/vim-signify'

" Syntax
Plug 'sheerun/vim-polyglot'
Plug 'fatih/vim-go', { 'for': 'go' }
Plug 'kchmck/vim-coffee-script', { 'for': ['coffee', 'eco'] } | Plug 'AndrewRadev/vim-eco', { 'for': 'eco' }

Plug 'slashmili/alchemist.vim', { 'for': 'elixir' }
call plug#end()
