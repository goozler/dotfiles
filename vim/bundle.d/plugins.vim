call plug#begin('~/.vim/plugged')
" Edit
Plug 'AndrewRadev/splitjoin.vim'
Plug 'Chiel92/vim-autoformat'
Plug 'DataWraith/auto_mkdir'
Plug 'Raimondi/delimitMate'
Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
Plug 'bronson/vim-trailing-whitespace'
Plug 'dkprice/vim-easygrep'
Plug 'easymotion/vim-easymotion'
Plug 'editorconfig/editorconfig-vim'
Plug 'gorkunov/smartpairs.vim'
Plug 'jeetsukumaran/vim-buffergator'
Plug 'jpalardy/vim-slime'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-easy-align'
Plug 'kshenoy/vim-signature'
Plug 'ludovicchabant/vim-gutentags'
Plug 'majutsushi/tagbar'
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
Plug 'moll/vim-node'
Plug 'skalnik/vim-vroom'
Plug 'szw/vim-maximizer'
Plug 'thinca/vim-localrc'
Plug 'tpope/vim-bundler'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-obsession'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'

" Snippets
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'

" Databases
Plug 'vim-scripts/dbext.vim'

" Lint
Plug 'scrooloose/syntastic' | Plug 'mtscout6/syntastic-local-eslint.vim' " , { 'on': 'SyntasticCheck' }

" Tmux
Plug 'benmills/vimux'

" UI
" Plug 'jonathanfilip/vim-lucius' " color scheme
Plug 'altercation/vim-colors-solarized' " color scheme
Plug 'scrooloose/nerdtree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }
Plug 'vim-airline/vim-airline' | Plug 'vim-airline/vim-airline-themes'

" Documentation
Plug 'danchoi/ri.vim'

" Git
Plug 'tpope/vim-fugitive'
if v:version >= 703
  Plug 'mhinz/vim-signify'
endif

" Syntax
Plug 'briancollins/vim-jst', { 'for': 'jst' }
Plug 'digitaltoad/vim-pug', { 'for': 'pug' }
Plug 'elzr/vim-json', { 'for': 'json' }
Plug 'fatih/vim-go', { 'for': 'go' }
Plug 'kchmck/vim-coffee-script', { 'for': ['coffee', 'eco'] } | Plug 'AndrewRadev/vim-eco', { 'for': 'eco' }
Plug 'pangloss/vim-javascript', { 'for': 'js' } | Plug 'mxw/vim-jsx'
Plug 'slim-template/vim-slim', { 'for': 'slim' }
Plug 'tpope/vim-haml', { 'for': ['haml', 'sass', 'scss'] }
Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }
call plug#end()
