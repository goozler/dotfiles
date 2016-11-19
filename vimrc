syntax on
filetype plugin indent on

source ~/.vim/bundle.d/plugins.vim

" ======================================
" BASIC SETTINGS
" ======================================
let mapleader      = ' '
let maplocalleader = ' '

" Faster redrawing
set ttyfast
set lazyredraw

set nu " enable line numbers
set timeout timeoutlen=500 ttimeoutlen=100 " fix slow O inserts
set nocompatible
set autoread
set list
set backspace=indent,eol,start " enable Backspace in insert mode
set hidden " allow unsaved background buffers and remember marks/undo for them
set history=10000 " remember more commands and search history
set scrolloff=7 " minimal lines around the cursor
set clipboard=unnamed " share copy buffer with system OS
set shortmess=aIT " short messages
set ve=block " allow put the cursor anyway in visual block mode
set nojs " insert only one space after . ? ! with a join command
set pastetoggle=<F9>
set synmaxcol=120
set nosol " keep the cursor in the same column when jump in file

" Mouse
silent! set ttymouse=xterm2
set mouse=a

" Shift-tab on GNU screen
" http://superuser.com/questions/195794/gnu-screen-shift-tab-issue
set t_kB=[Z

" UI SETTINGS
set term=screen-256color " 256-color terminal
set showcmd " show the (partial) command as it’s being typed
set showmode " show the current mode
set cursorline " highlight current line
set wildmenu " visual autocomplete for command menu
set showmatch  " highlight matching [{()}] "
set title " show the filename in the window titlebar
set ruler " show the cursor position
set nostartofline " don't reset cursor to start of line when moving around.
set shortmess=atI " don't show the intro message when starting Vim
set lcs=tab:>\ ,trail:·,nbsp:_ " show 'invisible' characters

" change cursor view for insert/normal mode
" tmux will only forward escape sequences to the terminal if surrounded by a DCS sequence
" http://sourceforge.net/mailarchive/forum.php?thread_name=AANLkTinkbdoZ8eNR1X2UobLTeww1jFrvfJxTMfKSq-L%2B%40mail.gmail.com&forum_name=tmux-users
if exists('$TMUX')
  let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
  let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
else
  let &t_SI = "\<Esc>]50;CursorShape=1\x7"
  let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif

" 80 chars/line
if exists('&colorcolumn')
  set colorcolumn=80 " higlight 80 column
  highlight ColorColumn ctermbg=darkgray
endif

" Disable error bells
set noerrorbells
set vb t_vb=

" SEARCHING
set incsearch " highlight dynamically as pattern is typed
set hlsearch " highlight searches
set gdefault " add the g flag to search/replace by default
" Make searches case-sensitive only if they contain upper-case characters
set ignorecase smartcase

" FOLDING
set foldenable          " dont fold by default
set foldmethod=indent   " fold based on spaces
set foldlevelstart=10   " open most folds by default
set foldnestmax=10      " 10 nested fold max

" INDENTATION/TABS
set tabstop=2     " read as
set softtabstop=2 " insert as
set expandtab     " tabs are spaces
set autoindent
set smartindent
set smarttab
set shiftwidth=2

" SPLITS
set splitbelow
set splitright

" BACKUPS/SWAPS
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if exists("&undodir")
  set undodir=~/.vim/undo
endif
" Don't create backups when editing files in certain directories
set backupskip=/tmp/*,/private/tmp/*

" STATUS LINE
set laststatus=2 " Always show status line
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1

" Ignore this paths
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*/build/*,*/node_modules/*,
set wildignore+=*/bower_components/*,*/test/files/*,*/features/vcr/*,*.cache

" Jump to the last cursor position
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal g`\"" | endif

" ======================================
" PLUGIN SETTINGS AND MAPPINGS
" ======================================
" NerdTree
let NERDTreeShowHidden=1 " Always show dot files
map <Leader>n :NERDTreeToggle<cr>
map <Leader>m :NERDTreeFind<cr>

" Syntastic
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_wq = 0
let g:syntastic_aggregate_errors = 1
let g:syntastic_loc_list_height = 5
let g:syntastic_ruby_checkers = ['mri', 'rubocop']
let g:syntastic_javascript_checkers = ['jshint', 'jscs']
let g:syntastic_slim_checkers = ['slim_lint', 'slimrb']
nnoremap <Leader>; :SyntasticToggleMode<cr>

" EasyMotion
map  / <Plug>(easymotion-sn)
omap / <Plug>(easymotion-tn)

" Fugitive
nmap <silent> <leader>g :Gstatus<cr>gg<c-n>
nmap <leader>d :Gdiff<cr>

" Vim-commentary
map  gc  <Plug>Commentary
nmap gcc <Plug>CommentaryLine

" Trailing whitespace
noremap <Leader>ss :FixWhitespace<cr>

" Splitjoin
let g:splitjoin_split_mapping = ''
let g:splitjoin_join_mapping = ''
nnoremap gss :SplitjoinSplit<cr>
nnoremap gsj :SplitjoinJoin<cr>

" Vroom
let g:vroom_use_spring = 0 " override in a local config
let g:vroom_cucumber_path = 'cucumber '
let g:vroom_map_keys = 0
let g:vroom_use_vimux = 1
nnoremap <silent> <leader>t :VroomRunTestFile<cr>
nnoremap <silent> <leader>T :VroomRunNearestTest<cr>
nnoremap <silent> <leader>l :VroomRunLastTest<cr>

" Color scheme
colorscheme lucius
LuciusWhite

" Buffergator
let g:buffergator_suppress_keymaps = 1
nnoremap <silent> <Leader>b :BuffergatorToggle<CR>
nnoremap <silent> gb :BuffergatorMruCyclePrev<CR>
nnoremap <silent> gB :BuffergatorMruCycleNext<CR>

" Signify
let g:signify_vcs_list = ['git']

" EasyAlign
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" Fzf
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-s': 'vsplit' }
nnoremap <silent> <C-b> :Buffers<cr>
nnoremap <silent> <expr> <C-p> (expand('%') =~ 'NERD_tree' ? "\<c-w>\<c-w>" : '').":Files\<cr>"
nnoremap <silent> <C-f> :Ag <C-R><C-W><cr>
nnoremap <silent> <Leader>f :Ag <C-R><C-A><cr>
vnoremap <silent> <C-f> y :Ag <C-R>"<cr>
vnoremap <silent> <Leader>f y :Ag <C-R>"<cr>
nnoremap <silent> <Leader>` :Marks<cr>

" YouCompleteMe
let g:ycm_show_diagnostics_ui = 0

" dbext
let g:dbext_default_type = 'ODBC'

" ri.vim
let g:ri_no_mappings=1
nnoremap <Leader>ri :call ri#OpenSearchPrompt(0)<cr> " horizontal split
nnoremap <Leader>rk :call ri#LookupNameUnderCursor()<cr> " keyword lookup

" slime
let g:slime_target = "tmux"
let g:slime_default_config = {"socket_name": "default", "target_pane": ":1.2"}

" maximazer
let g:maximizer_set_default_mapping = 0
nnoremap <silent><leader>z :MaximizerToggle!<CR>
vnoremap <silent><leader>z :MaximizerToggle!<CR>gv

" ======================================
" CUSTOM MAPPINGS
" ======================================
" jk to normal mode
inoremap jk <Esc>

" Fast split
nnoremap <silent> <leader>\ :vnew<cr>
nnoremap <silent> <leader>- :new<cr>

" qq to record, Q to replay (recursive map due to peekaboo)
nmap Q @q
xmap Q @q

" Scroll the viewport faster
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

" Faster save and quit
inoremap <C-s> <C-O>:update<cr>
nnoremap <C-s> :w<cr>
nnoremap <leader>s :w<cr>
nnoremap <leader>w :update<cr>
nnoremap <Leader>q :q<cr>
nnoremap <Leader>Q :q!<cr>
nnoremap <Leader>x :bd<cr>
nnoremap <Leader>X :bd!<cr>

" Close quickfix/location window
nnoremap <leader>c :cclose<bar>lclose<cr>

" Navigating over splits
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Fold on ,
noremap , za

" Replace findings
vnoremap // y/<C-R>"<cr>
nnoremap <Leader>r :%s/<C-R>//

" Make & run in tmux pane
nnoremap <silent> <F8> :call VimuxRunCommand('clear;make;./'.expand('%:r'))<CR>

" Remap ctrl-p ctrl-n
inoremap <C-j> <C-n>
inoremap <C-k> <C-p>
