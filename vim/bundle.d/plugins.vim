call plug#begin('~/.vim/plugged')
" Edit
Plug 'AndrewRadev/splitjoin.vim'
Plug 'DataWraith/auto_mkdir'
Plug 'Raimondi/delimitMate'
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'norcalli/nvim-colorizer.lua'
Plug 'bronson/vim-trailing-whitespace'
" Plug 'cakebaker/scss-syntax.vim', { 'for': ['sass', 'scss'] }
" Plug 'dkprice/vim-easygrep'
Plug 'easymotion/vim-easymotion'
Plug 'gorkunov/smartpairs.vim'
Plug 'janko-m/vim-test'
Plug 'jeetsukumaran/vim-buffergator'
Plug 'jpalardy/vim-slime' " REPL
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-easy-align'
Plug 'kshenoy/vim-signature'
" Plug 'ludovicchabant/vim-gutentags', { 'branch': 'vim7' }
Plug 'mattn/emmet-vim'
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
Plug 'moll/vim-node'
Plug 'sbdchd/neoformat'
Plug 'sgur/vim-editorconfig'
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
Plug 'mhinz/vim-signify'

" Syntax
" Plug 'fatih/vim-go' ", { 'do': ':GoUpdateBinaries', 'for': 'go' }
Plug 'sheerun/vim-polyglot'
" Plug 'kchmck/vim-coffee-script', { 'for': ['coffee', 'eco'] } | Plug 'AndrewRadev/vim-eco', { 'for': 'eco' }
Plug 'jparise/vim-graphql'

Plug 'autozimu/LanguageClient-neovim', {
    \ 'branch': 'next',
    \ 'do': 'bash install.sh',
    \ }
call plug#end()
