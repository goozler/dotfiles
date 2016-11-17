call plug#begin('~/.vim/plugged')
" Edit
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-easy-align'
Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
Plug 'Raimondi/delimitMate'
Plug 'AndrewRadev/splitjoin.vim'
Plug 'tpope/vim-commentary'
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
Plug 'easymotion/vim-easymotion'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'kshenoy/vim-signature'
Plug 'bronson/vim-trailing-whitespace'
Plug 'jeetsukumaran/vim-buffergator'
Plug 'skalnik/vim-vroom'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-bundler'
Plug 'thinca/vim-localrc'
Plug 'dkprice/vim-easygrep'
Plug 'DataWraith/auto_mkdir'
Plug 'jpalardy/vim-slime'
Plug 'szw/vim-maximizer'
Plug 'tpope/vim-obsession'

" Databases
Plug 'vim-scripts/dbext.vim'

" Lint
Plug 'scrooloose/syntastic' " , { 'on': 'SyntasticCheck' }

" Tmux
Plug 'benmills/vimux'

" UI
Plug 'scrooloose/nerdtree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }
Plug 'vim-airline/vim-airline' | Plug 'vim-airline/vim-airline-themes'
Plug 'jonathanfilip/vim-lucius' " color scheme

" Documentation
Plug 'danchoi/ri.vim'

" Git
Plug 'tpope/vim-fugitive'
if v:version >= 703
  Plug 'mhinz/vim-signify'
endif

" Syntax
Plug 'kchmck/vim-coffee-script', { 'for': 'coffee' }
Plug 'tpope/vim-haml', { 'for': ['haml', 'sass', 'scss'] }
Plug 'pangloss/vim-javascript', { 'for': 'js' }
Plug 'elzr/vim-json', { 'for': 'json' }
Plug 'slim-template/vim-slim', { 'for': 'slim' }
Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }
call plug#end()
