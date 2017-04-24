scriptencoding utf-8
set encoding=utf-8
if !has('nvim')
  syntax on
  filetype plugin indent on
endif

source ~/.vim/bundle.d/plugins.vim

" ======================================
" BASE SETTINGS
" ======================================
let mapleader      = ' '
let maplocalleader = ' '

" Faster redrawing
set lazyredraw
if !has('nvim')
  set ttyfast
endif

set clipboard=unnamed " share copy buffer with system OS
set hidden " allow unsaved background buffers and remember marks/undo for them
set list
set nojs " insert only one space after . ? ! with a join command
set nosol " keep the cursor in the same column when jump in file
set nu " enable line numbers
set pastetoggle=<F9>
set scrolloff=7 " minimal lines around the cursor
set shortmess=aIT " short messages
set synmaxcol=120
set timeout timeoutlen=500 ttimeoutlen=100 " fix slow O inserts
set ve=block " allow put the cursor anyway in visual block mode
set complete=.,w,b,u,t,i,kspell
if !has('nvim')
  set autoread
  set backspace=indent,eol,start " enable Backspace in insert mode
  set history=10000 " remember more commands and search history
  set nocompatible
endif

" Mouse
set mouse=a
if !has('nvim')
  silent! set ttymouse=xterm2
endif

" Shift-tab on GNU screen
" http://superuser.com/questions/195794/gnu-screen-shift-tab-issue
set t_kB=[Z

" UI SETTINGS
set cursorline " highlight current line
set nostartofline " don't reset cursor to start of line when moving around.
set ruler " show the cursor position
set shortmess=atI " don't show the intro message when starting Vim
set showcmd " show the (partial) command as it’s being typed
set showmatch  " highlight matching [{()}] "
set showmode " show the current mode
set title " show the filename in the window titlebar
set lcs=tab:▸\ ,trail:·,nbsp:_ " show 'invisible' characters
if has('nvim')
  " set termguicolors
else
  set term=screen-256color " 256-color terminal
  set wildmenu " visual autocomplete for command menu
endif

" change cursor view for insert/normal mode
if has('nvim')
  let $NVIM_TUI_ENABLE_CURSOR_SHAPE=1
else
  " tmux will only forward escape sequences to the terminal if surrounded by a DCS sequence
  " http://sourceforge.net/mailarchive/forum.php?thread_name=AANLkTinkbdoZ8eNR1X2UobLTeww1jFrvfJxTMfKSq-L%2B%40mail.gmail.com&forum_name=tmux-users
  if exists('$TMUX')
    let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
    let &t_SR = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=2\x7\<Esc>\\"
    let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
  else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_SR = "\<Esc>]50;CursorShape=2\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
  endif
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
set gdefault " add the g flag to search/replace by default
" Make searches case-sensitive only if they contain upper-case characters
set ignorecase smartcase
if !has('nvim')
  set hlsearch " highlight searches
  set incsearch " highlight dynamically as pattern is typed
endif

" FOLDING
set foldenable          " dont fold by default
set foldmethod=indent   " fold based on spaces
set foldlevelstart=10   " open most folds by default
set foldnestmax=10      " 10 nested fold max

" INDENTATION/TABS
set tabstop=2     " read as
set softtabstop=2 " insert as
set expandtab     " tabs are spaces
set smartindent
set shiftwidth=2
if !has('nvim')
  set autoindent
  set smarttab
endif

" SPLITS
set splitbelow
set splitright
set diffopt+=vertical

" BACKUPS/SWAPS
if !has('nvim')
  set backupdir=~/.vim/backups
  set directory=~/.vim/swaps
  if exists("&undodir")
    set undodir=~/.vim/undo
  endif
endif
" Don't create backups when editing files in certain directories
set backupskip=/tmp/*,/private/tmp/*

" STATUS LINE
if !has('nvim')
  set laststatus=2 " Always show status line
endif
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1

" Ignore this paths
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*/build/*,*/node_modules/*,
set wildignore+=*/bower_components/*,*/test/files/*,*/features/vcr/*,*.cache

" Jump to the last cursor position
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal g`\"" | endif

" ======================================
" COLOR SCHEME
" ======================================
set background=dark
colorscheme solarized

" ======================================
" PLUGIN SETTINGS AND MAPPINGS
" ======================================
" NerdTree
let NERDTreeShowHidden=1 " Always show dot files
map <Leader>n :NERDTreeToggle<cr>
map <Leader>m :NERDTreeFind<cr>

" Neomake
autocmd! BufWritePost * Neomake
" autocmd InsertLeave,TextChanged * silent! update | Neomake " fun but overhead
let g:neomake_javascript_enabled_makers = ['eslint']
let g:neomake_error_sign = {'text': 'x'}
let g:neomake_warning_sign = {'text': '!'}
let g:neomake_message_sign = {'text': '>'}
let g:neomake_info_sign = {'text': 'i'}

function! s:ToggleNeomakeMarkers()
  if g:neomake_place_signs
    echo 'Disable Neomake markers'
    let g:neomake_place_signs=0
    sign unplace *
    SignifyRefresh
  else
    echo 'Enable Neomake markers'
    let g:neomake_place_signs=1
    Neomake
  endif
endfunction

nnoremap <silent> <Leader>' :call <SID>ToggleNeomakeMarkers()<CR>

" IndentLines
nnoremap <Leader>; :IndentLinesToggle<CR>

" Go
let g:go_list_type = 'quickfix'

" EasyMotion
map  / <Plug>(easymotion-sn)
omap / <Plug>(easymotion-tn)

" EasyGrep
let g:EasyGrepFilesToExclude='.git,tags'
let g:EasyGrepCommand='ag'

" Fugitive
nmap <silent> <leader>g :Gstatus<cr>gg<c-n>
nmap <leader>d :Gdiff<cr>

" Vim-commentary
map  gc  <Plug>Commentary
nmap gcc <Plug>CommentaryLine

" Trailing whitespace
noremap <Leader>ss :FixWhitespace<cr>

" GutenTags
let g:gutentags_file_list_command = {
      \ 'markers': {
        \ 'bundler': 'bundle list --paths'
        \ },
      \ }
" Splitjoin
let g:splitjoin_split_mapping = ''
let g:splitjoin_join_mapping = ''
nnoremap gss :SplitjoinSplit<cr>
nnoremap gsj :SplitjoinJoin<cr>

" Vim-test
let test#strategy = "vimux"
nmap <silent> <leader>t :TestNearest<CR>
nmap <silent> <leader>T :TestFile<CR>
nmap <silent> <leader>l :TestLast<CR>

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

command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)

command! -bang -nargs=* Ag
  \ call fzf#vim#ag(<q-args>,
  \                 <bang>0 ? fzf#vim#with_preview('up:60%')
  \                         : fzf#vim#with_preview('right:50%:hidden', '?'),
  \                 <bang>0)

nnoremap <silent> <C-b> :Buffers<cr>
nnoremap <silent> <expr> <C-p> (expand('%') =~ 'NERD_tree' ? "\<c-w>\<c-w>" : '').":Files\<cr>"
nnoremap <silent> <C-f> :Ag! <C-R><C-W><cr>
nnoremap <silent> <Leader>f :Ag! <C-R><C-A><cr>
vnoremap <silent> <C-f> y :Ag! <C-R>"<cr>
vnoremap <silent> <Leader>f y :Ag! <C-R>"<cr>
nnoremap <silent> <Leader>` :Marks<cr>
nnoremap <silent> <C-g> :GFiles?<cr>
nnoremap <silent> <C-_> :BLines<cr>
nnoremap <silent> <Leader>/ :Lines<cr>
nnoremap <silent> q: :History:<cr>

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

" EditorConfig
let g:EditorConfig_exclude_patterns = ['fugitive://.*', 'scp://.*']

" Smartpairs
let g:smartpairs_nextpairs_key = 'n'
let g:smartpairs_revert_key = '<C-n>'

" Deoplete
let g:deoplete#enable_at_startup = 1

" Snippets
let g:UltiSnipsJumpForwardTrigger = "<tab>"
let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"

" Tagbar
nmap <C-t> :TagbarToggle<CR>

" Syntax JSX
" let g:jsx_ext_required = 0 " highlight .js files too

" ======================================
" CUSTOM MAPPINGS
" ======================================
" jk to normal mode
inoremap jk <Esc>

" Move up/down on wrapped lines
nmap j gj
nmap k gk

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
